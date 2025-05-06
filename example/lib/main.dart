import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  GetIt.I.registerSingletonAsync<SharedPreferences>(
    () async => await SharedPreferences.getInstance(),
  );
  runApp(const MyApp());
}
