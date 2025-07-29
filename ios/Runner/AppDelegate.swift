import UIKit
import Flutter
import GoogleMaps  // ✅ Import Google Maps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {


    GMSServices.provideAPIKey("AIzaSyBQsF-XgY8p88yFcBEBm_Kc9U6Cb9X3eDE")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
