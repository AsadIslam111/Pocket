# Keep Google Sign-In and Credential Manager classes
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** {
  *;
}

# Keep Google Identity Services (GIS) classes used by google_sign_in v7
-keep class com.google.android.gms.auth.api.identity.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }

# Keep Flutter Google Sign-In plugin
-keep class io.flutter.plugins.googlesignin.** { *; }
