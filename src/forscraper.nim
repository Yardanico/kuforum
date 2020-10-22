import std / [
  asyncdispatch, httpclient, sequtils,
  json, htmlparser, times, options,
  strformat, strutils
]

import karax / [karaxdsl, vdom]

type
  Rank = enum
    Spammer, Moderated, Troll, Banned, EmailUnconfirmed,
    User, Moderator, Admin

  Author = object
    name: string
    rank: Rank

  ForumPost = object
    id: Natural
    author: Author
    content: string
    created: Time
    likeCount: Natural

  ForumThreadId = distinct Natural

  ForumThread = ref object
    id: ForumThreadId
    activity: Time
    author: Author
    topic: string
    views: Natural
    posts: seq[ForumPost]
    # TODO: add categories

proc `$`(a: Author): string = a.name

const
  ThreadsUrl = "https://forum.nim-lang.org/threads.json"
  PostsUrl = "https://forum.nim-lang.org/posts.json"


proc getAuthor(n: JsonNode): Author =
  Author(
    name: n["name"].getStr(),
    rank: parseEnum[Rank](n["rank"].getStr()),
  )

proc getThread(n: JsonNode): ForumThread =
  ForumThread(
    id: ForumThreadId(n["id"].getInt()),
    topic: n["topic"].getStr(),
    views: n["views"].getInt(),
    activity: fromUnix(n["activity"].getInt())
  )

proc getLastThreads(count = 10): Future[seq[ForumThread]] {.async.} =
  var client = newAsyncHttpClient()
  var resp = await client.get(fmt"{ThreadsUrl}?count={count}")
  if resp.code != Http200:
    return

  let body = parseJson(await resp.body)

  for thr in body["threads"].getElems():
    let thread = getThread(thr)
    result.add thread

proc getThreadInfo(id: ForumThreadId): Future[ForumThread] {.async.} =
  var client = newAsyncHttpClient()
  var resp = await client.get(fmt"{PostsUrl}?id={int(id)}")
  if resp.code != Http200:
    return
  let data = parseJson(await resp.body)
  let thr = data["thread"]
  result = getThread(thr)
  result.author = getAuthor(thr["author"])

  for p in data["posts"].getElems():
    let post = ForumPost(
      id: p["id"].getInt(),
      author: getAuthor(p["author"]),
      content: p["info"]["content"].getStr(),
      created: fromUnix(p["info"]["creation"].getInt()),
      likeCount: len(p["likes"].getElems())
    )
    result.posts.add post

proc makeThreadEntry(thr: ForumThread): VNode =
  result = buildHtml():
    tr:
      td(class="thread-title"): text thr.topic
      td(class="thread-author"): text "placeholder" #$thr.author
      td(class="thread-views"): text $thr.views

proc makeThreadsList(threads: seq[ForumThread]): VNode =
  result = buildHtml():
    table(id="threads-list", class="table"):
      thead:
        tr:
          th: text "Topic"
          th: text "Author"
          th: text "Views"
      tbody:
        for thr in threads:
          makeThreadEntry(thr)

proc makeMainPage(threads: seq[ForumThread]): string =
  let vnode = buildHtml():
    html:
      head:
        title: text "Test forum"
      body:
        makeThreadsList(threads)

  result = $vnode

proc makePosts(thr: ForumThread): VNode =
  result = buildHtml():
    section(class = "container"):
      tdiv(id = "thread-title", class = "title"):
        text thr.topic
      tdiv(class = "posts"):
        for post in thr.posts:
          tdiv(id = $post.id, class = "post"):
            tdiv(class = "post-content"):
              verbatim(post.content)

proc makeThreadPage(thr: ForumThread): string =
  let vnode = buildHtml():
    html:
      head:
        title: text fmt"{thr.topic} - Nim forum"
      body:
        makePosts(thr)
  result = $vnode

import jester

routes:
  get "/":
    let thrs = await getLastThreads()
    resp makeMainPage(thrs)
  get "/thread@id":
    let id = try:
      ForumThreadId(parseInt(@"id"))
    except ValueError:
      resp "Invalid thread id"

    let thr = await getThreadInfo(id)
    resp makeThreadPage(thr)