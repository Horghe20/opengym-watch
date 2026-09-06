import { Capacitor } from '@capacitor/core'
import { WatchPlugin } from '../WatchPlugin.js'
import { exerciseNameFor } from './i18n.js'
import { modeOf } from './history.js'

// Formats routines to match the Swift Models.swift expectation
function formatForWatch(routines) {
  return routines.map(r => ({
    id: String(r.id),
    name: String(r.name),
    note: r.note ? String(r.note) : null,
    ex: (r.ex || []).map((exCfg, i) => {
      const mode = modeOf(exCfg)
      const isTimeBased = mode === 'time' || mode === 'cardio'
      const rawSets = exCfg.sets
      const targetSetsCount = (Array.isArray(rawSets) ? rawSets.length : (rawSets || 0))
        || (exCfg.target && exCfg.target.sets)
        || 1
      const sets = []
      for (let j = 0; j < targetSetsCount; j++) {
        sets.push({
          id: String(exCfg.id + '-' + j),
          reps: isTimeBased ? null : Number(((exCfg.target && exCfg.target.reps && exCfg.target.reps[j]) || 10)),
          weight: isTimeBased ? null : Number(((exCfg.target && exCfg.target.weight) || 0)),
          seconds: isTimeBased ? Number(((exCfg.target && exCfg.target.sec) || 30)) : null,
          isCompleted: false
        })
      }
      return {
        id: String(exCfg.id),
        name: String(exerciseNameFor(exCfg.id)),
        isTimeBased: Boolean(isTimeBased),
        restTimer: Number((exCfg.target && exCfg.target.restSec) || 90),
        sets
      }
    })
  }))
}

export const WearableService = {
  isSupported() {
    return Capacitor.getPlatform() === 'ios'
  },
  
  async sendRoutines(routines) {
    if (!this.isSupported()) return { success: false }
    try {
      const formatted = formatForWatch(routines)
      return await WatchPlugin.sendRoutine({ routines: formatted })
    } catch (e) {
      console.warn("Wearable sync failed", e)
      return { success: false }
    }
  },
  
  onWorkoutCompleted(callback) {
    if (!this.isSupported()) return null
    return WatchPlugin.addListener('onWorkoutCompleted', callback)
  },
  
  async saveWorkoutToHealthKit(workoutData) {
    if (!this.isSupported()) return { success: false }
    try {
      if (WatchPlugin.saveWorkoutToHealthKit) {
        return await WatchPlugin.saveWorkoutToHealthKit(workoutData)
      }
    } catch (e) {
      console.warn("HealthKit save failed", e)
      return { success: false }
    }
    return { success: false }
  }
}
