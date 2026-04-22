# PAX Neptune / DAL — required if you enable R8 minification (isMinifyEnabled true).
# Error like "q2.b.getInstance" is obfuscated NeptuneLite internals; keep com.pax.** so JNI/reflection work.

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# PAX public API and DAL (NeptuneLite JAR / device libs)
-keep class com.pax.** { *; }
-keepclassmembers class com.pax.** { *; }
-dontwarn com.pax.**

# Flutter plugin entry (if minified)
-keep class com.example.pax_sdk_package.** { *; }

# Reflection used from MainActivity.printBitmapOnPax
-keep class com.pax.neptunelite.api.NeptuneLiteUser { *; }

# Data Bank EPOS Open API (in-process on PAX A930 / A8900)
-keep class mn.databank.eposopenapi.** { *; }
-keepclassmembers class mn.databank.eposopenapi.** { *; }
-dontwarn mn.databank.eposopenapi.**
