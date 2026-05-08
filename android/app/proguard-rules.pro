-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# Pusher & Websocket Rules
-keep class com.pusher.** { *; }
-keep class org.java_websocket.** { *; }
-keep class com.neovisionaries.ws.client.** { *; }

# Gson — Keep ALL classes (Midtrans depends on internal Gson classes)
-keep class com.google.gson.** { *; }
-keep class com.google.gson.internal.** { *; }
-keep class com.google.gson.internal.bind.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Midtrans SDK
-keep class com.midtrans.** { *; }
-keep class com.midtrans.sdk.** { *; }
-dontwarn com.midtrans.**

-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
