# Decisiones de la fase 0

## Destino de despliegue — decidido antes de escribir la primera vista

El spec pide decidirlo en la fase 0 porque cambia como se escribe el proyecto.
Los tres requisitos duros son: **costo cero, sin backend, acceso controlado**.

**Decision: proyecto npm + Vite + TypeScript, con un build que emite un unico
archivo HTML autocontenido.**

Un solo archivo sirve simultaneamente a las tres opciones que plantea el spec:

| Destino | Como se usa el build |
|---|---|
| Artifact de Claude | Se publica `dist/racquetball.html`. Privado por defecto, se comparte a dedo. |
| Cloudflare Pages + Access | Se publica `dist/` entero. Mismo archivo, dominio propio y lista de correos. |
| Repo privado + `npm run dev` | Vite en local, sin desplegar nada. |

Consecuencias que hay que respetar al escribir codigo:

1. **Three.js va inline en el bundle, no por CDN.** El spec sugiere cargarlo desde
   `cdnjs` si el destino es un Artifact. Inlinearlo cumple igual la restriccion
   (solo se permiten scripts externos de cdnjs; cero scripts externos tambien vale)
   y ademas hace que la app funcione sin red. Cuesta ~600 KB del limite de 16 MB.
2. **Cero `fetch` a hosts externos.** Todos los datos son locales.
3. **Cero assets externos.** Sin fuentes de Google, sin imagenes remotas. Los
   iconos son SVG inline y la tipografia es la del sistema.
4. **Nada de backend, nunca.** El estado vive en `localStorage`, en JSON
   exportado y en el hash de la URL comprimido con `lz-string`.

GitHub Pages queda descartado como dice el spec: desde un repo privado exige plan
de pago, asi que "gratis" y "privado" no se dan a la vez.

## Convenio de radio de pelota — fijado aqui, verificado por test

Todas las pruebas de colision se hacen contra planos **desplazados hacia adentro
por `BALL.radius`**. Todo punto que se registra o se dibuja es el **centro** de la
pelota. El volumen donde puede estar ese centro es

```
[r, width-r] x [r, height-r] x [r, length-r]
```

`tests/engine-geometric.spec.ts` lo verifica en los seis lados y comprueba que
ningun punto de contacto mete la pelota dentro de la pared.

## Contrato `Trajectory` — congelado al terminar la fase 1

`src/core/types.ts` es el unico contrato entre el motor y todo lo demas. Las tres
vistas 2D son proyecciones ortograficas del mismo arreglo de puntos que usa la 3D:
planta descarta Y, alzado frontal descarta Z, alzado lateral descarta X. No hay
"motor 2D", y por construccion las vistas no pueden desincronizarse.
