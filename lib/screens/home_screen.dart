import 'dart:developer';
import 'dart:math' as math;

import 'package:aws_covid_care/models/user.dart';
import 'package:aws_covid_care/screens/covid_detail_screen.dart';
import 'package:aws_covid_care/screens/faq_screen.dart';
import 'package:aws_covid_care/screens/grid_items/symptoms_screen.dart';
import 'package:aws_covid_care/screens/myth_busters_screen.dart';
import 'package:aws_covid_care/screens/grid_items/prevention_screen.dart';
import 'package:aws_covid_care/services/notification.dart' as notif;

import 'package:aws_covid_care/services/firebase_authentication.dart';
import 'package:aws_covid_care/utils/constants.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const fetchBackground = "fetchBackground";

void callbackDispatcher() {
  Workmanager.executeTask((taskName, inputData) async {
    switch (taskName) {
      case fetchBackground:
        // Making a varibale in the Shared preferences.
        SharedPreferences prefs = await SharedPreferences.getInstance();
        int count = prefs.getInt(AppConstants.locationDected) ?? 0; // Setting it null, if it is a first try.
        count++; // Incrementing the count by one.
        // Setting the values in the Shared Preferences.
        prefs.setInt(AppConstants.locationDected, count);

        // Detecting the location.
        Position _fetchedUserLocation = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        // After collection of Data send it to the flutter_local_notifications. (Both Position Object & count are passed up to show them.)
        notif.Notification _notif = new notif.Notification();
        _notif.showNotificationWithoutSound(_fetchedUserLocation, count);
        break;
    }
    return Future.value(true);
  });
}

class GridItems {
  final String title;
  final Function onPressed;
  final String imageURL;

  GridItems({this.title, this.onPressed, this.imageURL});
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Authentication _authentication = Authentication();
  SharedPreferences _sharedPreferences;
  Firestore _firestore = Firestore.instance;
  User _userDetails;
  bool _tracing = false;

  List<GridItems> _gridItem;

  @override
  void initState() {
    super.initState();
    _gridItem = [
      GridItems(title: "MAP"),
      GridItems(title: "ANALYSIS"),
      GridItems(title: "STATISTICS"),
      GridItems(
          title: "PREVENTIONS",
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PreventionScreen()))),
      GridItems(
          title: "SYMPTOMS",
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SymptomsScreen()))),
      GridItems(title: "NEWS"),
    ];
  }

  Future<dynamic> _loadingEngine() async {
    log("Laoding Engine");
    _sharedPreferences = await SharedPreferences.getInstance();
    FirebaseUser _currentUser = await _authentication.getCurrentUser();
    _sharedPreferences.setString(AppConstants.userId, _currentUser.uid);

    String userID = _sharedPreferences.getString(AppConstants.userId);
    log("USER ID " + userID.toString());

    await _firestore.collection("users").document(userID).get().then((value) {
      _userDetails = User.fromJson(value.data);
      log(_userDetails.toJson().toString());
    });
    return _userDetails;
  }

  void _startBackgroundLocationTracker() async {
    Geolocator _geolocator = Geolocator();
    await _geolocator.checkGeolocationPermissionStatus();
    await _geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    GeolocationStatus _geoStatus = await _geolocator.checkGeolocationPermissionStatus();
    log("GEOSTATUS VALUE" + _geoStatus.value.toString());
    if (_geoStatus.value == 2) {
      log("Location Allowed!");
      setState(() {
        _tracing = true;
      });
      Workmanager.initialize(callbackDispatcher, isInDebugMode: false);
      Workmanager.registerPeriodicTask("1", fetchBackground, frequency: Duration(minutes: 15));
    } else {
      Widget alert = AlertDialog(
        title: Text("Allow location"),
        content: Text("We don't spy 🍻"),
        actions: [FlatButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
      );
      showDialog(context: context, builder: (_) => alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.height;

    return FutureBuilder(
      future: _loadingEngine(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (!snapshot.hasData)
          return Container(
            constraints: BoxConstraints.expand(),
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        return Scaffold(
          drawer: Drawer(
            child: Column(
              children: [
                UserAccountsDrawerHeader(
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Image.asset(
                        'assets/icons/mask_person.png',
                        width: 50.0,
                        height: 60.0,
                        fit: BoxFit.contain,
                      ),
                    ),
                    accountName: Text(
                      _userDetails.displayName.toUpperCase(),
                      style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
                    ),
                    accountEmail: Text(_userDetails.email)),
                ListTile(
                  onTap: () async {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MythBusterScreen()));
                  },
                  title: Text("Myth Busters"),
                  trailing: Icon(FontAwesomeIcons.fileMedicalAlt),
                ),
                ListTile(
                  onTap: () async {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CovidDetailScreen()));
                  },
                  title: Text("What is COVID-19?"),
                  trailing: Icon(FontAwesomeIcons.viruses),
                ),
                ListTile(
                  onTap: () async {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FAQScreen()));
                  },
                  title: Text("FAQ's"),
                  trailing: Icon(FontAwesomeIcons.questionCircle),
                ),
                ListTile(
                  onTap: () async {
                    await Workmanager.cancelByTag(fetchBackground).then((value) => _authentication.handleSignOut());
                    _sharedPreferences.remove(AppConstants.userId);
                  },
                  title: Text("Logout"),
                  trailing: Icon(Icons.exit_to_app),
                ),
              ],
            ),
          ),
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text("Home screen"),
            centerTitle: true,
            elevation: 0.0,
            actions: [
              IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {});
                  }),
              IconButton(
                  icon: Icon(_tracing ? Icons.location_on : Icons.location_off),
                  onPressed: () {
                    _startBackgroundLocationTracker();
                  }),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Column(
                children: [
                  SizedBox(
                    height: screenHeight * 0.22,
                    width: double.maxFinite,
                    child: CarouselSlider(
                      options: CarouselOptions(
                          autoPlay: true,
                          autoPlayInterval: Duration(milliseconds: 2400),
                          autoPlayAnimationDuration: Duration(milliseconds: 800),
                          enlargeCenterPage: true),
                      items: List.generate(
                          9,
                          (index) => Container(
                                decoration: BoxDecoration(
                                    color: Colors.primaries[math.Random().nextInt(18)],
                                    borderRadius: BorderRadius.circular(10.0)),
                              )),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    color: Colors.lightGreenAccent,
                    height: screenHeight * 0.18,
                  ),
                  AnimationLimiter(
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      childAspectRatio: 0.7,
                      children: List.generate(_gridItem.length, (index) {
                        return AnimationConfiguration.staggeredGrid(
                          columnCount: 3,
                          duration: Duration(milliseconds: 800),
                          position: index,
                          child: ScaleAnimation(
                            scale: 0.5,
                            child: InkWell(
                              onTap: _gridItem[index].onPressed,
                              child: Container(
                                margin: EdgeInsets.all(screenHeight * 0.008),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade300, borderRadius: BorderRadius.circular(10.0)),
                                child: Center(
                                  child: Text(_gridItem[index].title),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
