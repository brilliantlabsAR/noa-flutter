import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noa/util/check_internet_connection.dart';
import 'package:noa/api.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignIn {
  withApple() async {

  }


  Future<void> withGoogle() async {

    // String sampletoken = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjkzYjQ5NTE2MmFmMGM4N2NjN2E1MTY4NjI5NDA5NzA0MGRhZjNiNDMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI1MTA4MDk0MTA5MTQtOWw1NGFsczI1bTgzaHVqcml0dmszZWJuNnE2cWlib3AuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI1MTA4MDk0MTA5MTQtZnUwODc5ZWRzY2M2NmJjY2owN2FzNmc3MXZidXRpcjIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMTI1MDk1Mzc1OTU3NzAxMzIwMDQiLCJoZCI6InRlY2hub2V4cG9uZW50LmNvbSIsImVtYWlsIjoic3ViaGFqaXRwYWxAdGVjaG5vZXhwb25lbnQuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5hbWUiOiJTdWJoYWppdCBQYWwiLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EvQUNnOG9jTGd2NC1YUDdIaXA4RDBRRzgxMFJoMlZadHVBcVVWSDNCNE1JYnJEd3NGcGpaQjNBPXM5Ni1jIiwiZ2l2ZW5fbmFtZSI6IlN1Ymhhaml0IiwiZmFtaWx5X25hbWUiOiJQYWwiLCJpYXQiOjE3MTMxODcwMzQsImV4cCI6MTcxMzE5MDYzNH0.wUWY1EnB5pD7zGc4HSaSQjDSTTRV8bOEgWZol9RreaawKdjK20DV1rIMr7y0wMUeLmEZxYCoLfh6doO_9zSX4IAaKb7e6FDxxcQ1tQGa0bhdm5bvNb4R7Ya2hmNqfMjuIbNjnsHsrDjhrDsM5cw-7N09uOdqkhQdELAI_qv29NMq3Sikdc2gSqtdQt3WSYQmQjMtvFbGR0HXr47kgeRSVUWS7eHlMJGRM_NJi2cQGNWgFthLdznoQNOqgxLE2R8uxQbI511TqhrzKQFk9j2ebD_Hcf0munwke9wH2jzLOxs3LjbFjustwE4fBUzFyGFz6tWD4kdQdjllRtGpbS2lYQ";
    //
    //
    // final preferences = await SharedPreferences.getInstance();
    // await preferences.setString('userToken', sampletoken);
    try {
      await checkInternetConnection();

      final GoogleSignInAccount? account = await GoogleSignIn(
        clientId: dotenv.env['ANDROID_GOOGLE_CLIENT_ID'],
        scopes: ['email'],
      ).signIn();

      final GoogleSignInAuthentication auth = await account!.authentication;

      await NoaApi.obtainAuthToken(
        auth.idToken ?? "",
        NoaApiAuthProvider.google,
      );
    } on NoaApiServerError catch (error) {


      return Future.error(NoaApiServerError(error.serverErrorCode));
    } catch (error) {

      return Future.error(error);
    }
  }

  withDiscord() async {}
}
