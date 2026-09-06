#import <Capacitor/Capacitor.h>

// Definisce il plugin in Objective-C in modo che Capacitor possa registrarlo
CAP_PLUGIN(WatchPlugin, "WatchPlugin",
    CAP_PLUGIN_METHOD(sendRoutine, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(saveWorkoutToHealthKit, CAPPluginReturnPromise);
)
