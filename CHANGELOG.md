## 0.1.0

Initial version.

### new support commands
+ KV commands
    + del
    + exists
    + expire
    + keys
    + get
    + set
    + getdel
+ list commands
    + lrange
    + rpush
+ transaction commands
    + multi
    + exec
    + discard
+ pub/sub commands
    + psubscribe
    + publish

## 0.1.1

add codec export

## 0.2.0

add new commands

+ lset
+ lpush

## 0.3.0

support multiple elements for `lpush` and `rpush` commands.

## 0.3.1

fix bug: did not fetch SELECT command's reply.

## 0.4.0

add new commands

+ discard
+ getdel