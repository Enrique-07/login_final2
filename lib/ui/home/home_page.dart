import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_login_screen/como_gasto_icons.dart';
import 'package:flutter_login_screen/como_gasto_localizations.dart';
import 'package:flutter_login_screen/month_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rect_getter/rect_getter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter_login_screen/expenses_repository.dart';
import 'package:flutter_login_screen/utils.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  var globalKey = RectGetter.createGlobalKey();
  Rect buttonRect;

  PageController _controller;
  int currentPage = DateTime.now().month - 1;
  Stream<QuerySnapshot> _query;
  GraphType currentType = GraphType.LINES;

  @override
  void initState() {
    super.initState();

    _controller = PageController(
      initialPage: currentPage,
      viewportFraction: 0.4,
    );

    setupNotificationPlugin();
  }

  Widget _bottomAction(IconData icon, Function callback) {
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon),
      ),
      onTap: callback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpensesRepository>(
        builder: (BuildContext context, ExpensesRepository db, Widget child) {
      _query = db.queryByMonth(currentPage + 1);

      return Scaffold(
        bottomNavigationBar: BottomAppBar(
          notchMargin: 8.0,
          shape: CircularNotchedRectangle(),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _bottomAction(ComoGastoIcons.stats_bars, () {
                setState(() {
                  currentType = GraphType.LINES;
                });
              }),
              _bottomAction(ComoGastoIcons.pie_chart, () {
                setState(() {
                  currentType = GraphType.PIE;
                });
              }),
              SizedBox(width: 48.0),
              _bottomAction(ComoGastoIcons.cart, () {}),
              _bottomAction(ComoGastoIcons.settings, () {

                Navigator.pushNamed(context, '/settings');
              }),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: RectGetter(
          key: globalKey,
          child: FloatingActionButton(
            child: Icon(ComoGastoIcons.plus),
            onPressed: () {
              buttonRect = RectGetter.getRectFromKey(globalKey);

              Navigator.of(context).pushNamed('/add', arguments: buttonRect);
            },
          ),
        ),
        body: _body(),
      );
    });
  }

  Widget _body() {
    ComoGastoLocalizations localizations = Localizations.of<ComoGastoLocalizations>(context, ComoGastoLocalizations);
    return SafeArea(
      child: Column(
        children: <Widget>[
          _selector(localizations),
          StreamBuilder<QuerySnapshot>(
            stream: _query,
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> data) {
              if (data.connectionState == ConnectionState.active) {
                if (data.data.documents.length > 0) {
                  return MonthWidget(
                    days: daysInMonth(currentPage + 1),
                    documents: data.data.documents,
                    graphType: currentType,
                    month: currentPage,
                  );
                } else {
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Image.asset('assets/no_data.png'),
                        SizedBox(height: 80),
                        Text(
                          localizations.t('home.emptyList'),
                          style: Theme.of(context).textTheme.caption,
                        )
                      ],
                    ),
                  );
                }
              }

              return Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _pageItem(String name, int position) {
    var _alignment;
    final selected = TextStyle(
      fontSize: 20.0,
      fontWeight: FontWeight.bold,
      color: Colors.blueGrey,
    );
    final unselected = TextStyle(
      fontSize: 20.0,
      fontWeight: FontWeight.normal,
      color: Colors.blueGrey.withOpacity(0.4),
    );

    if (position == currentPage) {
      _alignment = Alignment.center;
    } else if (position > currentPage) {
      _alignment = Alignment.centerRight;
    } else {
      _alignment = Alignment.centerLeft;
    }

    return Align(
      alignment: _alignment,
      child: Text(
        name,
        style: position == currentPage ? selected : unselected,
      ),
    );
  }

  Widget _selector(ComoGastoLocalizations localizations) {
    return SizedBox.fromSize(
      size: Size.fromHeight(70.0),
      child: PageView(
        onPageChanged: (newPage) {
          var db = Provider.of<ExpensesRepository>(context);

          setState(() {
            currentPage = newPage;
            _query = db.queryByMonth(currentPage + 1);
          });
        },
        controller: _controller,
        children: <Widget>[
          _pageItem(localizations.t("months.jan"), 0),
          _pageItem(localizations.t("months.feb"), 1),
          _pageItem(localizations.t("months.mar"), 2),
          _pageItem(localizations.t("months.apr"), 3),
          _pageItem(localizations.t("months.may"), 4),
          _pageItem(localizations.t("months.jun"), 5),
          _pageItem(localizations.t("months.jul"), 6),
          _pageItem(localizations.t("months.aug"), 7),
          _pageItem(localizations.t("months.sep"), 8),
          _pageItem(localizations.t("months.oct"), 9),
          _pageItem(localizations.t("months.nov"), 10),
          _pageItem(localizations.t("months.dec"), 11),
        ],
      ),
    );
  }

  void setupNotificationPlugin() {
    flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();

    // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var initializationSettingsAndroid =
        new AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = new IOSInitializationSettings(
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );
    var initializationSettings = new InitializationSettings(
      initializationSettingsAndroid,
      initializationSettingsIOS,
    );

    flutterLocalNotificationsPlugin
        .initialize(
      initializationSettings,
      onSelectNotification: onSelectNotification,
    )
        .then((init) {
      setupNotification();
    });
  }

  Future onSelectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
    }
    await Navigator.push(
      context,
      new MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  Future onDidReceiveLocalNotification(
      int id, String title, String body, String payload) async {
    // display a dialog with the notification details, tap ok to go to another page
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              content: Text("Don't forget to add your expenses"),
              actions: <Widget>[
                FlatButton(
                  child: Text('Ok'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ));
  }

  void setupNotification() async {
    var time = new Time(16, 11, 0);
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'daily-notifications', 'Daily Notifications', 'Daily Notifications');
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.showDailyAtTime(0, 'Spend-o-meter',
        "Don't forget to add your expenses", time, platformChannelSpecifics);
  }
}
