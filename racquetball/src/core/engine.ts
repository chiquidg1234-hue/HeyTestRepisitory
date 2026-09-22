/**
 * Selector de motor. Es el unico punto por el que las vistas piden una
 * simulacion; no importan `engine-geometric` ni `engine-ballistic` a mano.
 */

import { simulateGeometric } from './engine-geometric.js';
import type { Shot, SimOptions, Trajectory } from './types.js';

export const simulate = (shot: Shot, opts: SimOptions = {}): Trajectory => {
  switch (opts.model ?? 'geometric') {
    case 'geometric':
      return simulateGeometric(shot, opts);
    case 'ballistic':
      // FASE 7. Hasta entonces, el geometrico es el unico motor.
      return simulateGeometric(shot, opts);
  }
};

export { simulateGeometric };
