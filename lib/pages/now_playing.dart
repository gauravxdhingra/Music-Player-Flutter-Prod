import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
// import 'package:musicplayer/pages/artistcard.dart';
// import 'package:musicplayer/util/artistInfo.dart';
import 'package:flute_music_player/flute_music_player.dart';
import 'package:flutter/material.dart';
// import 'package:musicplayer/database/database_client.dart';
// import 'package:musicplayer/util/lastplay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_player/database/database_client.dart';
import 'package:test_player/pages/artistcard.dart';
import 'package:test_player/util/artistInfo.dart';
import 'package:test_player/util/lastplay.dart';

class NowPlaying extends StatefulWidget {
  final int mode;
  final List<Song> songs;
  int index;
  final DatabaseClient db;

  NowPlaying(this.db, this.songs, this.index, this.mode);

  @override
  State<StatefulWidget> createState() {
    return new _StateNowPlaying();
  }
}

double widthX;
double sHeightX;

class _StateNowPlaying extends State<NowPlaying>
    with SingleTickerProviderStateMixin {
  MusicFinder player;
  Duration duration;
  Duration position;
  bool isPlaying = false;
  Song song;
  int isFav = 1;
  int repeatOn = 0;
  Orientation orientation;
  AnimationController _animationController;
  Animation<Color> _animateColor;
  bool isOpened = true;
  Animation<double> _animateIcon;
  Timer timer;
  bool _showArtistImage;

  get durationText => duration != null
      ? duration.toString().split('.').first.substring(3, 7)
      : '';

  get positionText => position != null
      ? position.toString().split('.').first.substring(3, 7)
      : '';

  @override
  void initState() {
    super.initState();
    _showArtistImage = false;
    initAnim();
    initPlayer();
  }

  @override
  void dispose() {
    super.dispose();
    _animationController.dispose();
  }

  initAnim() {
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 500))
          ..addListener(() {
            setState(() {});
          });
    _animateIcon =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animateColor = ColorTween(
      begin: Colors.blueGrey[400].withOpacity(0.7),
      end: Colors.blueGrey[400].withOpacity(0.9),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        0.00,
        1.00,
        curve: Curves.linear,
      ),
    ));
  }

  animateForward() {
    _animationController.forward();
  }

  animateReverse() {
    _animationController.reverse();
  }

  void initPlayer() async {
    if (player == null) {
      player = MusicFinder();
      MyQueue.player = player;
      var pref = await SharedPreferences.getInstance();
      pref.setBool("played", true);
    }
    //  int i= await widget.db.isfav(song);
    setState(() {
      if (widget.mode == 0) {
        player.stop();
      }
      updatePage(widget.index);
      isPlaying = true;
    });
    player.setDurationHandler((d) => setState(() {
          duration = d;
        }));
    player.setPositionHandler((p) => setState(() {
          position = p;
        }));
    player.setCompletionHandler(() {
      onComplete();
      setState(() {
        position = duration;
        if (repeatOn != 1) ++widget.index;
        song = widget.songs[widget.index];
      });
    });
    player.setErrorHandler((msg) {
      setState(() {
        player.stop();
        duration = new Duration(seconds: 0);
        position = new Duration(seconds: 0);
      });
    });
  }

  void updatePage(int index) {
    MyQueue.index = index;
    song = widget.songs[index];
    song.timestamp = new DateTime.now().millisecondsSinceEpoch;
    if (song.count == null) {
      song.count = 0;
    } else {
      song.count++;
    }
    widget.db.updateSong(song);
    isFav = song.isFav;
    player.play(song.uri);
    animateReverse();
    setState(() {
      isPlaying = true;
    });
  }

  void playPause() {
    if (isPlaying) {
      player.pause();
      animateForward();
      setState(() {
        isPlaying = false;
        //  song = widget.songs[widget.index];
      });
    } else {
      player.play(song.uri);
      animateReverse();
      setState(() {
        //song = widget.songs[widget.index];
        isPlaying = true;
      });
    }
  }

  Future next() async {
    player.stop();
    // int i=await widget.db.isfav(song);
    setState(() {
      int i = widget.index + 1;
      if (repeatOn != 1) ++widget.index;

      if (i >= widget.songs.length) {
        i = widget.index = 0;
      }

      updatePage(widget.index);
    });
  }

  Future prev() async {
    player.stop();
    //   int i=await  widget.db.isfav(song);
    setState(() {
      int i = --widget.index;
      if (i < 0) {
        widget.index = 0;
        i = widget.index;
      }
      updatePage(i);
    });
  }

  void onComplete() {
    next();
  }

  dynamic getImage(Song song) {
    if (song.albumArt == null) return null;
    return song == null ? null : new File.fromUri(Uri.parse(song.albumArt));
  }

  GlobalKey<ScaffoldState> scaffoldState = new GlobalKey();

  @override
  Widget build(BuildContext context) {
    orientation = MediaQuery.of(context).orientation;
    return new Scaffold(
      key: scaffoldState,
      body: song != null
          ? portrait()
          : Center(
              child: CircularProgressIndicator(),
            ),
      backgroundColor: Colors.white,
    );
  }

  void _showBottomSheet() {
    showModalBottomSheet(
        context: context,
        builder: (builder) {
          return new Container(
              decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6.0),
                          topRight: Radius.circular(6.0))),
                  color: Color(0xFFFAFAFA)),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Scrollbar(
                child: new ListView.builder(
                  physics: ClampingScrollPhysics(),
                  itemCount: widget.songs.length,
                  padding: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width * 0.02,
                      right: MediaQuery.of(context).size.width * 0.02,
                      top: 10.0),
                  itemBuilder: (context, i) => new Column(
                    children: <Widget>[
                      new ListTile(
                        leading: new CircleAvatar(
                          backgroundImage: getImage(widget.songs[i]) != null
                              ? FileImage(
                                  getImage(widget.songs[i]),
                                )
                              // child:  new Image.file(

                              //         height: 120.0,
                              //         fit: BoxFit.cover,
                              //       )
                              : null,
                          child: getImage(widget.songs[i]) == null
                              ? Text(
                                  widget.songs[i].title[0].toUpperCase())
                              : null,
                        ),
                        title: new Text(widget.songs[i].title,
                            maxLines: 1, style: new TextStyle(fontSize: 16.0)),
                        subtitle: Row(
                          children: <Widget>[
                            new Text(
                              widget.songs[i].artist,
                              maxLines: 1,
                              style: new TextStyle(
                                  fontSize: 12.0, color: Colors.black54),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 5.0, right: 5.0),
                              child: Text("-"),
                            ),
                            Text(
                                new Duration(
                                        milliseconds: widget.songs[i].duration)
                                    .toString()
                                    .split('.')
                                    .first
                                    .substring(3, 7),
                                style: new TextStyle(
                                    fontSize: 11.0, color: Colors.black54))
                          ],
                        ),
                        trailing: widget.songs[i].id ==
                                MyQueue.songs[MyQueue.index].id
                            ? new Icon(Icons.play_circle_filled,
                                color: Colors.blueGrey[700])
                            : null,
                        onTap: () {
                          setState(() {
                            MyQueue.index = i;
                            player.stop();
                            updatePage(MyQueue.index);
                            Navigator.pop(context);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ));
        });
  }

  Widget portrait() {
    double width = MediaQuery.of(context).size.width;
    widthX = width;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    sHeightX = statusBarHeight;
    final double cutRadius = 8.0;
    return Stack(
      children: <Widget>[
        // Container(
        //     height: MediaQuery.of(context).size.width,
        //     color: Colors.white,
        //     child: getImage(song) != null
        //         ? Image.file(
        //             getImage(song),
        //             fit: BoxFit.fitHeight,
        //           )
        //         : Image.asset(
        //             "images/music.jpg",
        //             fit: BoxFit.fitWidth,
        //             width: MediaQuery.of(context).size.width,
        //           )),
        // Positioned(
        //   top: width,
        //   child: Container(
        //     color: Colors.white,
        //     height: MediaQuery.of(context).size.height - width,
        //     width: width,
        //   ),
        // ),
        // BackdropFilter(
        //   filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        //   child: Container(
        //     height: width,
        //     decoration:
        //         new BoxDecoration(color: Colors.grey[900].withOpacity(0.5)),
        //   ),
        // ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: width * 0.06 * 2),
            child: Container(
              width: width - 2 * width * 0.06,
              height: width - width * 0.06,
              child: new AspectRatio(
                aspectRatio: 15 / 15,
                child: Hero(
                  tag: song.id,
                  child: getImage(song) != null
                      ? Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                              // borderRadius:
                              //     BorderRadius.circular(cutRadius),
                              image: DecorationImage(
                                  image: FileImage(getImage(song)),
                                  fit: BoxFit.cover)),
                          child: Stack(
                            children: <Widget>[
                              _showArtistImage
                                  ? Container(
                                      width: width - 2 * width * 0.06,
                                      height: width - width * 0.06,
                                      child: GetArtistDetail(
                                        artist: song.artist,
                                        artistSong: song,
                                      ),
                                    )
                                  : Container(),
                              // Positioned(
                              //   bottom: -width * 0.15,
                              //   right: -width * 0.15,
                              //   child: Container(
                              //     decoration: ShapeDecoration(
                              //         color: Colors.white,
                              //         shape: BeveledRectangleBorder(
                              //             borderRadius: BorderRadius.only(
                              //                 topLeft: Radius.circular(
                              //                     width * 0.15)))),
                              //     height: width * 0.15 * 2,
                              //     width: width * 0.15 * 2,
                              //   ),
                              // ),
                              // Positioned(
                              //   bottom: 0.0,
                              //   right: 0.0,
                              //   child: Padding(
                              //     padding:
                              //         EdgeInsets.only(right: 4.0, bottom: 6.0),
                              //     child: Text(
                              //       durationText,
                              //       style: TextStyle(
                              //         color: Colors.black,
                              //         fontWeight: FontWeight.w600,
                              //         fontSize: 18.0,
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                        )
                      // )
                      // )
                      : Material(
                          // color: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(cutRadius)),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              Icon(
                                Icons.music_note,
                                size: 150,
                              ),
                              // Image.asset(
                              //   "images/back.jpg",
                              //   fit: BoxFit.cover,
                              // ),
                              // Positioned(
                              //   bottom: -width * 0.15,
                              //   right: -width * 0.15,
                              //   child: Container(
                              //     decoration: ShapeDecoration(
                              //         color: Colors.white,
                              //         shape: BeveledRectangleBorder(
                              //             borderRadius: BorderRadius.only(
                              //                 topLeft: Radius.circular(
                              //                     width * 0.15)))),
                              //     height: width * 0.15 * 2,
                              //     width: width * 0.15 * 2,
                              //   ),
                              // ),
                              // Positioned(
                              //   bottom: 0.0,
                              //   right: 0.0,
                              //   child: Padding(
                              //     padding:
                              //         EdgeInsets.only(right: 4.0, bottom: 6.0),
                              //     child: Text(
                              //       durationText,
                              //       style: TextStyle(
                              //         color: Colors.black,
                              //         fontSize: 16.0,
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: width * 1.11),
            child: Container(
              height: MediaQuery.of(context).size.height - width * 1.11,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: Container(
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 10.0, right: 10.0, top: 5),
                              child: new Text(
                                '${song.title}\n',
                                style: new TextStyle(
                                    color: Colors.black.withOpacity(0.85),
                                    fontSize: 19,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            new Text(
                              "${song.artist}\n",
                              style: new TextStyle(
                                  color: Colors.black.withOpacity(0.7),
                                  fontSize: 14.0,
                                  letterSpacing: 1.8,
                                  height: 1.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          positionText,
                          style: TextStyle(
                              fontSize: 13.0,
                              color: Color(0xaa373737),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0),
                        ),
                        Expanded(
                          child: Slider(
                            min: 0.0,
                            activeColor:
                                Colors.blueGrey.shade400.withOpacity(0.5),
                            inactiveColor:
                                Colors.blueGrey.shade300.withOpacity(0.3),
                            value: position?.inMilliseconds?.toDouble() ?? 0.0,
                            onChanged: (double value) =>
                                player.seek((value / 1000).roundToDouble()),
                            max: song.duration.toDouble() + 1000,
                          ),
                        ),
                        Text(
                          durationText,
                          style: TextStyle(
                              fontSize: 13.0,
                              color: Color(0xaa373737),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 15.0),
                        child: new Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            new IconButton(
                                icon: isFav == 0
                                    ? new Icon(
                                        Icons.favorite_border,
                                        color: Colors.blueGrey,
                                        size: 15.0,
                                      )
                                    : new Icon(
                                        Icons.favorite,
                                        color: Colors.blueGrey,
                                        size: 15.0,
                                      ),
                                onPressed: () {
                                  setFav(song);
                                }),
                            Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 15.0)),
                            new IconButton(
                              splashColor: Colors.blueGrey[200],
                              highlightColor: Colors.transparent,
                              icon: new Icon(
                                Icons.skip_previous,
                                color: Colors.blueGrey,
                                size: 32.0,
                              ),
                              onPressed: prev,
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 20.0, right: 20.0),
                              child: FloatingActionButton(
                                backgroundColor: _animateColor.value,
                                child: new AnimatedIcon(
                                    icon: AnimatedIcons.pause_play,
                                    progress: _animateIcon),
                                onPressed: playPause,
                              ),
                            ),
                            new IconButton(
                              splashColor:
                                  Colors.blueGrey[200].withOpacity(0.5),
                              highlightColor: Colors.transparent,
                              icon: new Icon(
                                Icons.skip_next,
                                color: Colors.blueGrey,
                                size: 32.0,
                              ),
                              onPressed: next,
                            ),
                            Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 15.0)),
                            new IconButton(
                                icon: (repeatOn == 1)
                                    ? Icon(
                                        Icons.repeat,
                                        color: Colors.blueGrey,
                                        size: 15.0,
                                      )
                                    : Icon(
                                        Icons.repeat,
                                        color: Colors.blueGrey.withOpacity(0.5),
                                        size: 15.0,
                                      ),
                                onPressed: () {
                                  repeat1();
                                }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: width,
                    color: Colors.white,
                    child: FlatButton(
                      onPressed: _showBottomSheet,
                      highlightColor: Colors.blueGrey[200].withOpacity(0.1),
                      child: Text(
                        "UP NEXT",
                        style: TextStyle(
                            color: Colors.black.withOpacity(0.8),
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold),
                      ),
                      splashColor: Colors.blueGrey[200].withOpacity(0.1),
                    ),
                  )
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  Future<void> repeat1() async {
    setState(() {
      if (repeatOn == 0) {
        repeatOn = 1;
        //widget.repeat.write(1);
      } else {
        repeatOn = 0;
        // widget.repeat.write(0);
      }
    });
  }

  Future<void> setFav(song) async {
    int i = await widget.db.favSong(song);
    setState(() {
      if (isFav == 1)
        isFav = 0;
      else
        isFav = 1;
    });
  }
}
