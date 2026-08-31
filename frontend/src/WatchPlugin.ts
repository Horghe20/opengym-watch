import { registerPlugin, PluginListenerHandle } from '@capacitor/core';

export interface WatchPluginInterface {
  /**
   * Invia un array di routine (schede di allenamento) all'Apple Watch
   */
  sendRoutine(options: { routines: any[] }): Promise<{ success: boolean }>;

  /**
   * Ascolta quando l'Apple Watch completa un allenamento
   */
  addListener(
    eventName: 'onWorkoutCompleted',
    listenerFunc: (workoutData: any) => void
  ): Promise<PluginListenerHandle>;
}

// Registra il plugin in Capacitor
export const WatchPlugin = registerPlugin<WatchPluginInterface>('WatchPlugin');
