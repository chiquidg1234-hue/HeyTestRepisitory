/**
 * Punto de entrada. Monta las vistas, las conecta al estado y arranca el
 * bucle de reproduccion. Todo lo demas cuelga de `ui/state.ts`.
 */

import './style.css';

import { CourtView2D } from './render2d/courtSvg.js';
import {
  PROJECTIONS,
  type ProjectionId,
} from './render2d/projections.js';
import { clearNode, el, mustGet } from './ui/dom.js';
import { state, subscribe, update, type LayoutId } from './ui/state.js';

const views = new Map<ProjectionId, CourtView2D>();

// ------------------------------------------------------------- vistas 2D

const mount2D = (): void => {
  for (const projection of PROJECTIONS) {
    const host = mustGet(`viewport-${projection.id}`);
    const view = new CourtView2D(projection);
    host.appendChild(
      el('div', { class: 'viewport-label', text: projection.label }),
    );
    host.appendChild(view.svg);
    host.appendChild(
      el('div', { class: 'viewport-hint', text: projection.hint }),
    );
    views.set(projection.id, view);
  }
};

// ------------------------------------------------------------- pestanas

const LAYOUTS: { id: LayoutId; label: string }[] = [
  { id: 'split', label: 'Todo' },
  { id: '3d', label: '3D' },
  { id: 'plan', label: 'Planta' },
  { id: 'front', label: 'Frontal' },
  { id: 'side', label: 'Lateral' },
];

const mountLayoutTabs = (): void => {
  const host = mustGet('layout-tabs');
  for (const layout of LAYOUTS) {
    const tab = el('button', {
      class: 'tab',
      type: 'button',
      role: 'tab',
      'data-layout': layout.id,
      text: layout.label,
    });
    tab.addEventListener('click', () => update({ layout: layout.id }));
    host.appendChild(tab);
  }
};

const syncLayout = (): void => {
  mustGet('viewports').dataset.layout = state.layout;
  for (const tab of document.querySelectorAll<HTMLElement>('[data-layout]')) {
    if (tab.classList.contains('tab')) {
      tab.setAttribute(
        'aria-selected',
        String(tab.dataset.layout === state.layout),
      );
    }
  }
};

// ------------------------------------------------------------- timeline

let scrub: HTMLInputElement;
let timeLabel: HTMLElement;
let playButton: HTMLButtonElement;

const mountTimeline = (): void => {
  const host = mustGet('timeline');
  clearNode(host);

  playButton = el('button', {
    class: 'btn btn--icon',
    type: 'button',
    title: 'Reproducir (espacio)',
    text: '▶',
  });
  playButton.addEventListener('click', () => togglePlay());

  scrub = el('input', {
    type: 'range',
    min: 0,
    max: 1,
    step: 0.001,
    value: 0,
    'aria-label': 'Instante de la trayectoria',
  }) as HTMLInputElement;
  scrub.addEventListener('input', () => {
    update({ playing: false, playhead: Number(scrub.value) });
  });

  timeLabel = el('span', { class: 'timeline-time', text: '0.000 s' });

  const rate = el('select', { class: 'btn', 'aria-label': 'Velocidad' });
  for (const [label, value] of [
    ['1/20', 0.05],
    ['1/8', 0.125],
    ['1/4', 0.25],
    ['1/2', 0.5],
    ['1x', 1],
  ] as const) {
    const option = el('option', { value, text: label });
    if (value === state.playRate) option.setAttribute('selected', '');
    rate.appendChild(option);
  }
  rate.addEventListener('change', () =>
    update({ playRate: Number((rate as HTMLSelectElement).value) }),
  );

  host.append(playButton, scrub, timeLabel, rate);
};

const togglePlay = (): void => {
  if (!state.playing && state.playhead >= state.trajectory.totalTime - 1e-6) {
    update({ playhead: 0 });
  }
  update({ playing: !state.playing });
};

const syncTimeline = (): void => {
  const total = Math.max(state.trajectory.totalTime, 1e-3);
  scrub.max = String(total);
  if (document.activeElement !== scrub) scrub.value = String(state.playhead);
  timeLabel.textContent = `${state.playhead.toFixed(3)} s / ${total.toFixed(2)} s`;
  playButton.textContent = state.playing ? '❚❚' : '▶';
};

// ------------------------------------------------------------- redibujo

const redraw = (): void => {
  for (const view of views.values()) {
    view.draw(state.trajectory, {
      playhead: state.playhead,
      origin: state.shot.origin,
      aim: state.aim,
    });
  }
  syncTimeline();
};

// ------------------------------------------------------------- bucle

let lastFrame = 0;

const frame = (now: number): void => {
  const dt = lastFrame === 0 ? 0 : (now - lastFrame) / 1000;
  lastFrame = now;

  if (state.playing) {
    const total = state.trajectory.totalTime;
    const next = state.playhead + dt * state.playRate;
    if (next >= total) update({ playhead: total, playing: false });
    else update({ playhead: next });
  }

  requestAnimationFrame(frame);
};

// ------------------------------------------------------------- teclado

const mountKeyboard = (): void => {
  window.addEventListener('keydown', (e) => {
    const target = e.target as HTMLElement | null;
    if (target && /^(INPUT|SELECT|TEXTAREA)$/.test(target.tagName)) return;
    if (e.key === ' ') {
      e.preventDefault();
      togglePlay();
    }
  });
};

// ------------------------------------------------------------- arranque

const boot = (): void => {
  mount2D();
  mountLayoutTabs();
  mountTimeline();
  mountKeyboard();

  subscribe((_s, changed) => {
    if (changed.has('layout')) syncLayout();
    redraw();
  });

  syncLayout();
  redraw();
  requestAnimationFrame(frame);
};

boot();
