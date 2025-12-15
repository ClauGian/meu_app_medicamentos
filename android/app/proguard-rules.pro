-keep class com.ryanheise.just_audio.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keepclassmembers class ** {
  @com.google.android.exoplayer2.** *;
}