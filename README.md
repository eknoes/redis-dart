[Redis](http://redis.io/) client for [dart](https://www.dartlang.org) 
=====================================================================

Redis protocol  parser and client  
It is designed to be both fast and simple to use.

### Currently supported features:

* [transactions](http://redis.io/topics/transactions) wrapper for executing multiple commands in atomic way
* [pubsub](#pubsub) helper with aditional internal dispatching
* [unicode](#unicode) - strings are UTF8 encoded when sending and decoded when received 
* [performance](#fast) - this counts as future too
* raw commands - this enables sending any command as raw data :)


## Simple

Redis protocol is composition of array, strings(and bulk) and integers.
For example executing command `SET key value` is no more that serializing
array of strings `["SET","key","value"]`. Commands can be executed by

    Future f = command.send_object(["SET","key","value"]);

This enables sending any command.

## Fast

It can execute and process more than 100K SET or GET operations per second - tested on my laptop.
This is code that yields such result and can give you first impression

    import 'package:redis/redis.dart';
    main(){
      const int N = 200000;
      int start;
      RedisConnection conn = new RedisConnection();
      conn.connect('localhost',6379).then((Command command){
        print("test started, please wait ...");
        start =  new DateTime.now().millisecondsSinceEpoch;
        command.pipe_start();
        for(int i=1;i<N;i++){ 
          command.set("test $i","$i")
          .then((v){
            assert(v=="OK");
          });
        }
        //last command will be executed and then processed last
        command.set("test $N","$N").then((v){
          assert(v=="OK"); 
          double diff = (new DateTime.now().millisecondsSinceEpoch - start)/1000.0;
          double perf = N/diff;
          print("$N operations done in $diff s\nperformance $perf/s");
        });
        command.pipe_end();
      });
    }


## Transactions

[Transactions](http://redis.io/topics/transactions) by redis protocol are started by command MULTI and then completed with command EXEC.
`.multi()` and `.exec()` and `class Transaction` are implemented as
additional helpers for checking result of each command executed during transaction.

    import 'package:redis/redis.dart';
    ...
    
    RedisConnection conn = new RedisConnection();
    conn.connect('localhost',6379).then((Command command){    
      command.multi().then((Transaction trans){
          trans.send_object(["SET","val","0"]);
          for(int i=0;i<200000;++i){
            trans.send_object(["INCR","val"]).then((v){
              assert(i==v);
            });
          }
          trans.send_object(["GET","val"]).then((v){
            print("number is now $v");
          });
          trans.exec();
      });
    });

Take note here, that Future returned by `trans.send_object()` is executed after 
`.exec()` so make sure you dont try to call `.exec()` inside of such Future, beacause
command will never complete. 



## Unicode

By default UTF8 encoding/decoding for string is used. Each string is coverted in binary 
array using UTF8 encoding. This makes ascii string compatible in both direction.


## [PubSub](http://redis.io/topics/pubsub)

PubSub is helper for dispatching recevied messages. 
First, create new `PubSubCommand` from existing `Command`

    PubSubCommand pubsub=new PubSubCommand(command);

Once `PubSubCommand` is created, old `Command` is invalidated and should not be used
on same connection. `PubSubCommand` allows commands

    void subscribe(List<String> channels) 
    void psubscribe(List<String> channels)
    void unsubscribe(List<String> channels)
    void punsubscribe(List<String> channels)

and additional `Subscription` getter 

    Subscription getSubscription();
      
`Subscription` enables local message dispatching.
It enables registering callbacks trough `.add(String pattern,Function callback)`
Unlike Redis rich pattern matching, this pattern allows only for optional `*` wildchar
at the end of string. Message consumers can be added only trough `Subscription`.

In this example, from all messages from redis that `Subscription` will receive,
only those that begins with abra and have at least 5 letters will be dispatched.

    subscription.add("abra*",(String chan,String message){
      print("on channel: $chan message: $message");
    });

 Here is complete example from test code.
 
    import 'package:redis/redis.dart';
    
    main(){
      RedisConnection conn1 = new RedisConnection();
      RedisConnection conn2 = new RedisConnection();
      Command command; //on conn1
      PubSubCommand pubsub; //on conn2
      
      conn1.connect('localhost',6379)
      .then((Command cmd){
        command = cmd;
        return conn2.connect('localhost',6379);
      })
      .then((Command cmd){ 
        pubsub=new PubSubCommand(cmd);
        pubsub.psubscribe(["a*","b*","a*"]);
        Subscription sub = pubsub.getSubscription();
        sub.add("*",(k,v){
          print("$k $v");
         });
      })
      .then((_){ 
        command.send_object(["PUBLISH","aaa","aa"]);
        command.send_object(["PUBLISH","bbb","bb"]);
        command.send_object(["PUBLISH","ccc","cc"]); 
      });
    }
    
## Todo 
In near future:

- Better documentation
- Implement all "generic commands" with named commands
- Better error handling - that is ability to recover from error
- Spell check code

## Changes

### 0.4.0

- PubSub interface is made simpler but backward incompatible :(
- README is updated
  
