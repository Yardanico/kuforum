# Types taken from the nimforum
#[
Copyright (C) 2018 Andreas Rumpf, Dominik Picheta

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 ]#

import options

type
  # If you add more "Banned" states, be sure to modify forum's threadsQuery too.
  Rank* {.pure.} = enum ## serialized as 'status'
    Spammer          ## spammer: every post is invisible
    Moderated        ## new member: posts manually reviewed before everybody
                     ## can see them
    Troll            ## troll: cannot write new posts
    Banned           ## A non-specific ban
    EmailUnconfirmed ## member with unconfirmed email address. Their posts
                     ## are visible, but cannot make new posts. This is so that
                     ## when a user with existing posts changes their email,
                     ## their posts don't disappear.
    User             ## Ordinary user
    Moderator        ## Moderator: can change a user's rank
    Admin            ## Admin: can do everything

  User* = object
    id*: Option[string] # TODO: this is not how it's on nimforum, but it's needed
    name*: string
    avatarUrl*: string
    lastOnline*: int64
    previousVisitAt*: int64 ## Tracks the "last visit" line position
    rank*: Rank
    isDeleted*: bool

  ForumThread* = object
    id*: int
    topic*: string
    category*: Category
    author*: User
    users*: seq[User]
    replies*: int
    views*: int
    activity*: int64 ## Unix timestamp
    creation*: int64 ## Unix timestamp
    isLocked*: bool
    isSolved*: bool

  ThreadList* = ref object
    threads*: seq[ForumThread]
    moreCount*: int ## How many more threads are left

  Category* = object
    id*: int
    name*: string
    description*: string
    color*: string
    numTopics*: int

  CategoryList* = ref object
    categories*: seq[Category]

  PostList* = ref object
    thread*: ForumThread
    history*: seq[ForumThread] ## If the thread was edited this will contain the
                          ## older versions of the thread (title/category
                          ## changes). TODO
    posts*: seq[Post]

  PostInfo* = object
    creation*: int64
    content*: string

  Post* = ref object
    id*: int
    author*: User
    likes*: seq[User] ## Users that liked this post.
    seen*: bool ## Determines whether the current user saw this post.
                ## I considered using a simple timestamp for each thread,
                ## but that wouldn't work when a user navigates to the last
                ## post in a thread for example.
    history*: seq[PostInfo] ## If the post was edited this will contain the
                            ## older versions of the post.
    info*: PostInfo
    moreBefore*: seq[int]
    replyingTo*: Option[PostLink]

  PostLink* = object ## Used by profile
    creation*: int64
    topic*: string
    threadId*: int
    postId*: int
    author*: Option[User] ## Only used for `replyingTo`.

proc `$`*(u: User): string = u.name