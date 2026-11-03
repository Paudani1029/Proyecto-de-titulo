# Entrenar el modelo propio de Lumina

Objetivo: que Lumina detecte lo que ningún modelo público con licencia comercial
detecta y es peligroso para una persona ciega: **escaleras, escaleras mecánicas,
puertas, soleras, postes, bolardos, hoyos, tapas de alcantarilla, pasos
peatonales, barreras, rampas, andamios y señales de piso mojado**. La lista está
en [`clases_lumina.py`](clases_lumina.py).

El modelo resultante **conserva las 365 clases de Objects365** y les suma las nuevas.

## El proceso

```
 1. Fotos ──▶ 2. Etiquetado automático ──▶ 3. Revisión a mano ──▶ 4. Entrenamiento ──▶ 5. App
  (celular)     autoetiquetar.py             CVAT                   entrenar_dfine.py     exportar_dfine.py
```

### 1. Tomar las fotos (lo más importante)

El modelo aprende de lo que ve. Si las fotos no se parecen a lo que verá la app, no
servirá en la calle.

- **Con el mismo celular y a la altura a la que se usará la app** (pecho), mirando
  hacia adelante, como lo haría el usuario.
- **Calles, veredas, estaciones de metro, edificios, malls y casas de Chile.**
  Distintos barrios: veredas rotas, soleras pintadas, rejillas, cuestas.
- **Variedad:** día, noche, lluvia, sombra, contraluz; de lejos (5 m) y de cerca (50 cm);
  de frente y en diagonal. Escaleras **subiendo y bajando**.
- **Cantidad:** apunten a **300-1000 apariciones por clase**. Una foto puede tener
  varias clases. También sirven fotos *sin* ninguna clase nueva (enseñan qué NO es).
- **Atajo:** grabar video caminando y sacar 1-2 cuadros por segundo:
  `ffmpeg -i video.mp4 -vf fps=2 -q:v 2 fotos/video1_%04d.jpg`
- **Privacidad:** en la calle salen personas. Estas fotos son solo para entrenar:
  no las publiquen, guárdenlas en un lugar privado y bórrenlas cuando ya no sirvan.
  No suban fotos donde se identifique a alguien sin su consentimiento.
- **No usar fotos de internet ni datasets sin revisar su licencia.** Cityscapes y
  Mapillary Vistas, por ejemplo, prohíben el uso comercial. Las fotos propias no
  tienen ese problema.

Guarden todo en una carpeta, por ejemplo `datos/fotos/` (está en `.gitignore`).

### 2. Etiquetado automático

```bash
pip install torch torchvision transformers scipy pillow
python autoetiquetar.py datos/fotos datos/auto.json
```

Usa dos modelos con licencia Apache 2.0:

- **Grounding DINO** busca las clases nuevas a partir de texto.
- **D-FINE Objects365** etiqueta las 365 clases que la app ya conoce. Esto es
  necesario: si una foto tiene un basurero sin etiqueta, el modelo aprendería que
  eso "no es nada" y lo olvidaría.

En CPU tarda varios segundos por foto. Con GPU (Colab) es mucho más rápido.

### 3. Revisión a mano en CVAT

El etiquetado automático se equivoca: confunde postes con árboles, se le escapan
soleras, marca puertas que son ventanas. **Revisen todas las cajas de las clases
nuevas**. Las de las 365 clases conocidas basta con mirarlas por encima.

1. Instalar [CVAT](https://github.com/cvat-ai/cvat) (MIT, gratis) o usar app.cvat.ai.
2. Crear una tarea con las fotos e importar `auto.json` como **COCO 1.0**.
3. Corregir: borrar cajas falsas, ajustar bordes y agregar lo que faltó.
4. Exportar como **COCO 1.0** → `datos/revisadas.json`.

Reglas para que todos etiqueten igual:

| Clase | Qué incluye la caja |
|---|---|
| escalera | Todos los peldaños visibles, desde el primero hasta el último |
| puerta | El marco completo, esté abierta o cerrada |
| solera | El tramo de borde de vereda visible (caja larga y baja) |
| poste | Solo el poste, desde el suelo hasta donde se vea |
| hoyo | El borde del hoyo o zanja |
| paso peatonal | Todas las franjas visibles |
| barrera | La reja, valla o cinta de obra completa |

Si una cosa es dudosa (muy lejos o tapada en más de la mitad), no la etiqueten.

### 4. Entrenamiento (con GPU)

En una CPU tardaría días. Usen **Google Colab** o **Kaggle**, que tienen GPU gratis:

```bash
python entrenar_dfine.py datos/revisadas.json datos/fotos salida --epocas 40 --lote 8
```

Cada época muestra cuánto encuentra de cada clase nueva en las fotos de validación:

```
Época 12: pérdida 4.211 · validación 4.870
    stairs           recall 81% (43/53) · precisión 77%
    door             recall 88% (61/69) · precisión 85%
```

El **recall** dice qué porcentaje de las escaleras reales encontró. Para una clase
de peligro importa más que la precisión: es peor no avisar de una escalera que
avisar de más. Si una clase queda baja, faltan fotos de ella.

Para probar que todo corre (sin GPU, 2 pasos): `--pasos-max 2 --lote 2`.

### 5. Llevarlo a la app

```bash
python ../modelos/exportar_dfine.py salida/mejor ../../assets/modelos/dfine-s-lumina-v1.onnx
python ../modelos/generar_clases_obj365.py   # agrega los nombres en español de las clases nuevas
```

Después hay que agregar el modelo en `lib/services/detector_onnx.dart` y sumar las
clases peligrosas a las listas de `lib/logica/generador_respuestas.dart`.
