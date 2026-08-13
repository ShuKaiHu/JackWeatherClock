# kotlinx.serialization — keep serializers for the persisted models.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class com.shukaihu.rainyclock.** {
    *** Companion;
}
-keepclasseswithmembers class com.shukaihu.rainyclock.** {
    kotlinx.serialization.KSerializer serializer(...);
}
