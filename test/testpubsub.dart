part of testredis;

// helper function to check
// if Stream data is same as provided test Iterable
Future _test_rec_msg(Stream s, List l) {
  var it = l.iterator;
  return s
      .where((v) => (v[0] == "message"))
      .take(l.length)
      .every((v){
          return it.moveNext() && (it.current.toString() == v.toString());
        });
}

Future test_pubsub() {
  Command command; //on conn1 tosend commands
  Stream pubsubstream; //on conn2 to rec c

  RedisConnection conn = new RedisConnection();
  return conn.connect('localhost', 6379).then((Command cmd) {
    command = cmd;
    RedisConnection conn = new RedisConnection();
    return conn.connect('localhost', 6379);
  }).then((Command cmd) {
    PubSub pubsub = new PubSub(cmd);
    pubsub.subscribe(["monkey"]);
    pubsubstream = pubsub.getStream();
    return pubsubstream; //TODO fix logic correct, no just working
  }).then((_) {
    //bussy wait for prevous to be subscibed
    return Future.doWhile(() {
      return command.send_object(["PUBSUB", "NUMSUB", "monkey"])
          .then((v) => v[1] == 0);
    }).then((_) {
      //at thuis point one is subscribed
      return command.send_object(["PUBLISH", "monkey", "banana"])
          .then((_) => command.send_object(["PUBLISH", "monkey", "peanut"]))
          .then((_) => command.send_object(["PUBLISH", "lion", "zebra"]));
    });
  }).then((_) {
    var expect = [["message", "monkey", "banana"],["message", "monkey", "peanut"]];
    return  _test_rec_msg(pubsubstream,expect)
    .then(( r){
       assert(r is bool);
       if(r != true)
         throw "errror test_pubsub2";
    });

  });
}

Future test_pubsub_performance(int N) {
  Command command; //on conn1 tosend commands
  Stream pubsubstream; //on conn2 to rec c
  RedisConnection conn = new RedisConnection();
  return conn.connect('localhost', 6379).then((Command cmd) {
    command = cmd;
    RedisConnection conn = new RedisConnection();
    return conn.connect('localhost', 6379);
  }).then((Command cmd) {
    PubSub pubsub = new PubSub(cmd);
    pubsub.subscribe(["monkey"]);
    pubsubstream = pubsub.getStream();
    return pubsubstream;
  }).then((_) {
    //bussy wait for prevous to be subscibed
    return Future.doWhile(() {
      return command.send_object(["PUBSUB", "NUMSUB", "monkey"])
          .then((v) => v[1] == 0);
    }).then((_) {
      //at thuis point one is subscribed
      for(int i=0;i<N;++i){
        command.send_object(["PUBLISH", "monkey", "banana"]);
      }
    });
  }).then((_) {
    int counter = 0;
    var expected = ["message", "monkey", "banana"];
    var subscription;
    Completer comp = new Completer();
    subscription = pubsubstream.listen((var data){
      counter++;
      if(counter == N){
        subscription.cancel();
        comp.complete("OK"); 
      }
    });
    return comp.future;
  });
}
