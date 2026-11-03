"""Clases propias de Lumina: lo que un modelo público no detecta y es peligroso
para una persona ciega.

Cada clase tiene:
- clave:    nombre interno (el que usa la app, igual que 'person' o 'trash bin can')
- consulta: texto en inglés para Grounding DINO (el etiquetador automático).
            Varias formas separadas por ' . ' ayudan a que la encuentre.
- nombre / articulo: cómo la dice Lumina en voz alta.

Para agregar una clase: añade una entrada AL FINAL (nunca cambies el orden de
las existentes: el número de cada clase depende de su posición).
"""

CLASES_NUEVAS = [
    dict(clave='stairs', consulta='staircase . stairs . steps',
         nombre='escalera', articulo='la'),
    dict(clave='escalator', consulta='escalator',
         nombre='escalera mecánica', articulo='la'),
    dict(clave='door', consulta='door',
         nombre='puerta', articulo='la'),
    dict(clave='curb', consulta='curb . sidewalk edge',
         nombre='solera', articulo='la'),
    dict(clave='pole', consulta='pole . post',
         nombre='poste', articulo='el'),
    dict(clave='bollard', consulta='bollard',
         nombre='bolardo', articulo='el'),
    dict(clave='pothole', consulta='pothole . hole in the ground',
         nombre='hoyo', articulo='el'),
    dict(clave='manhole', consulta='manhole cover . drain grate',
         nombre='tapa de alcantarilla', articulo='la'),
    dict(clave='crosswalk', consulta='crosswalk . zebra crossing',
         nombre='paso peatonal', articulo='el'),
    dict(clave='barrier', consulta='barrier . fence . gate . construction barrier',
         nombre='barrera', articulo='la'),
    dict(clave='ramp', consulta='ramp . wheelchair ramp',
         nombre='rampa', articulo='la'),
    dict(clave='scaffolding', consulta='scaffolding',
         nombre='andamio', articulo='el'),
    dict(clave='wet floor sign', consulta='wet floor sign . caution sign',
         nombre='señal de piso mojado', articulo='la'),
]

# Modelo del que se parte: sabe 365 clases y las conserva.
MODELO_BASE = 'ustc-community/dfine-small-obj365'
