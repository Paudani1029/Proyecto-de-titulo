"""Genera lib/models/clases_obj365.dart a partir de clases_obj365.txt y de
herramientas/entrenamiento/clases_lumina.py (clases propias de Lumina).

Cada línea de TABLA es:  Nombre en Objects365 | clave | nombre en español | artículo
- Si 'clave' es una clase COCO (ej. 'person'), se reutiliza su nombre en español de
  clases_coco.dart y toda la lógica existente (alertas, sinónimos) sigue funcionando.
- Si 'clave' va vacía, la clave es el nombre en minúsculas y hay que dar nombre/artículo.

Uso (desde la raíz del proyecto): python herramientas/modelos/generar_clases_obj365.py
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / 'herramientas' / 'entrenamiento'))
from clases_lumina import CLASES_NUEVAS  # noqa: E402

TABLA = """
Person|person
Sneakers||zapatillas|las
Chair|chair
Other Shoes||zapatos|los
Hat||sombrero|el
Car|car
Lamp||lámpara|la
Glasses||lentes|los
Bottle|bottle
Desk||escritorio|el
Cup|cup
Street Lights||poste de luz|el
Cabinet/shelf||mueble|el
Handbag/Satchel|handbag
Bracelet||pulsera|la
Plate||plato|el
Picture/Frame||cuadro|el
Helmet||casco|el
Book|book
Gloves||guantes|los
Storage box||caja|la
Boat|boat
Leather Shoes||zapatos de cuero|los
Flower||flor|la
Bench|bench
Potted Plant|potted plant
Bowl/Basin|bowl
Flag||bandera|la
Pillow||almohada|la
Boots||botas|las
Vase|vase
Microphone||micrófono|el
Necklace||collar|el
Ring||anillo|el
SUV||camioneta|la
Wine Glass|wine glass
Belt||cinturón|el
Monitor/TV|tv
Backpack|backpack
Umbrella|umbrella
Traffic Light|traffic light
Speaker||parlante|el
Watch||reloj de pulsera|el
Tie|tie
Trash bin Can||basurero|el
Slippers||pantuflas|las
Bicycle|bicycle
Stool||taburete|el
Barrel/bucket||balde|el
Van||furgón|el
Couch|couch
Sandals||sandalias|las
Basket||canasto|el
Drum||tambor|el
Pen/Pencil||lápiz|el
Bus|bus
Wild Bird|bird
High Heels||zapatos de taco|los
Motorcycle|motorcycle
Guitar||guitarra|la
Carpet||alfombra|la
Cell Phone|cell phone
Bread||pan|el
Camera||cámara|la
Canned||lata|la
Truck|truck
Traffic cone||cono|el
Cymbal||platillo|el
Lifesaver||salvavidas|el
Towel||toalla|la
Stuffed Toy|teddy bear
Candle||vela|la
Sailboat||velero|el
Laptop|laptop
Awning||toldo|el
Bed|bed
Faucet||llave de agua|la
Tent||carpa|la
Horse|horse
Mirror||espejo|el
Power outlet||enchufe|el
Sink|sink
Apple|apple
Air Conditioner||aire acondicionado|el
Knife|knife
Hockey Stick||palo de hockey|el
Paddle||remo|el
Pickup Truck||camioneta|la
Fork|fork
Traffic Sign||señal de tránsito|la
Balloon||globo|el
Tripod||trípode|el
Dog|dog
Spoon|spoon
Clock|clock
Pot||olla|la
Cow|cow
Cake|cake
Dinning Table|dining table
Sheep|sheep
Hanger||colgador|el
Blackboard/Whiteboard||pizarra|la
Napkin||servilleta|la
Other Fish||pez|el
Orange/Tangerine|orange
Toiletry||artículo de aseo|el
Keyboard|keyboard
Tomato||tomate|el
Lantern||farol|el
Machinery Vehicle||maquinaria pesada|la
Fan||ventilador|el
Green Vegetables||verduras|las
Banana|banana
Baseball Glove|baseball glove
Airplane|airplane
Mouse|mouse
Train|train
Pumpkin||zapallo|el
Soccer||pelota de fútbol|la
Skiboard|skis
Luggage|suitcase
Nightstand||velador|el
Tea pot||tetera|la
Telephone||teléfono fijo|el
Trolley||carro|el
Head Phone||audífonos|los
Sports Car||auto deportivo|el
Stop Sign|stop sign
Dessert||postre|el
Scooter||scooter|el
Stroller||coche de bebé|el
Crane||grúa|la
Remote|remote
Refrigerator|refrigerator
Oven|oven
Lemon||limón|el
Duck||pato|el
Baseball Bat|baseball bat
Surveillance Camera||cámara de seguridad|la
Cat|cat
Jug||jarro|el
Broccoli|broccoli
Piano||piano|el
Pizza|pizza
Elephant|elephant
Skateboard|skateboard
Surfboard|surfboard
Gun||pistola|la
Skating and Skiing shoes||patines|los
Gas stove||cocina|la
Donut|donut
Bow Tie||humita|la
Carrot|carrot
Toilet|toilet
Kite|kite
Strawberry||frutilla|la
Other Balls|sports ball
Shovel||pala|la
Pepper||pimentón|el
Computer Box||computador|el
Toilet Paper||papel higiénico|el
Cleaning Products||producto de limpieza|el
Chopsticks||palillos|los
Microwave|microwave
Pigeon||paloma|la
Baseball||pelota de béisbol|la
Cutting/chopping Board||tabla de picar|la
Coffee Table||mesa de centro|la
Side Table||mesa lateral|la
Scissors|scissors
Marker||plumón|el
Pie||tarta|la
Ladder||escalera de mano|la
Snowboard|snowboard
Cookies||galletas|las
Radiator||radiador|el
Fire Hydrant|fire hydrant
Basketball||pelota de básquetbol|la
Zebra|zebra
Grape||uvas|las
Giraffe|giraffe
Potato||papa|la
Sausage||salchicha|la
Tricycle||triciclo|el
Violin||violín|el
Egg||huevo|el
Fire Extinguisher||extintor|el
Candy||dulce|el
Fire Truck||carro de bomberos|el
Billiards||bola de pool|la
Converter||adaptador|el
Bathtub||tina|la
Wheelchair||silla de ruedas|la
Golf Club||palo de golf|el
Briefcase||maletín|el
Cucumber||pepino|el
Cigar/Cigarette||cigarro|el
Paint Brush||pincel|el
Pear||pera|la
Heavy Truck||camión pesado|el
Hamburger||hamburguesa|la
Extractor||campana de cocina|la
Extension Cord||alargador|el
Tong||pinzas|las
Tennis Racket|tennis racket
Folder||carpeta|la
American Football||balón de fútbol americano|el
earphone||audífono|el
Mask||mascarilla|la
Kettle||hervidor|el
Tennis||pelota de tenis|la
Ship||barco|el
Swing||columpio|el
Coffee Machine||cafetera|la
Slide||resbalín|el
Carriage||carruaje|el
Onion||cebolla|la
Green beans||porotos verdes|los
Projector||proyector|el
Frisbee|frisbee
Washing Machine/Drying Machine||lavadora|la
Chicken||gallina|la
Printer||impresora|la
Watermelon||sandía|la
Saxophone||saxofón|el
Tissue||pañuelos desechables|los
Toothbrush|toothbrush
Ice cream||helado|el
Hot-air balloon||globo aerostático|el
Cello||violonchelo|el
French Fries||papas fritas|las
Scale||pesa|la
Trophy||trofeo|el
Cabbage||repollo|el
Hot dog|hot dog
Blender||juguera|la
Peach||durazno|el
Rice||arroz|el
Wallet/Purse||billetera|la
Volleyball||pelota de vóleibol|la
Deer||ciervo|el
Goose||ganso|el
Tape||cinta adhesiva|la
Tablet||tablet|la
Cosmetics||cosmético|el
Trumpet||trompeta|la
Pineapple||piña|la
Golf Ball||pelota de golf|la
Ambulance||ambulancia|la
Parking meter|parking meter
Mango||mango|el
Key||llaves|las
Hurdle||valla|la
Fishing Rod||caña de pescar|la
Medal||medalla|la
Flute||flauta|la
Brush||cepillo|el
Penguin||pingüino|el
Megaphone||megáfono|el
Corn||choclo|el
Lettuce||lechuga|la
Garlic||ajo|el
Swan||cisne|el
Helicopter||helicóptero|el
Green Onion||cebollín|el
Sandwich|sandwich
Nuts||nueces|las
Speed Limit Sign||señal de velocidad máxima|la
Induction Cooker||cocina de inducción|la
Broom||escoba|la
Trombone||trombón|el
Plum||ciruela|la
Rickshaw||bicitaxi|el
Goldfish||pez dorado|el
Kiwi fruit||kiwi|el
Router/modem||módem|el
Poker Card||naipes|los
Toaster|toaster
Shrimp||camarón|el
Sushi||sushi|el
Cheese||queso|el
Notepaper||papel de notas|el
Cherry||cereza|la
Pliers||alicate|el
CD||disco compacto|el
Pasta||fideos|los
Hammer||martillo|el
Cue||taco de pool|el
Avocado||palta|la
Hamimelon||melón|el
Flask||frasco|el
Mushroom||champiñón|el
Screwdriver||destornillador|el
Soap||jabón|el
Recorder||flauta dulce|la
Bear|bear
Eggplant||berenjena|la
Board Eraser||borrador de pizarra|el
Coconut||coco|el
Tape Measure/Ruler||huincha de medir|la
Pig||cerdo|el
Showerhead||ducha|la
Globe||globo terráqueo|el
Chips||papas fritas de bolsa|las
Steak||bistec|el
Crosswalk Sign||señal de paso peatonal|la
Stapler||corchetera|la
Camel||camello|el
Formula 1||auto de carreras|el
Pomegranate||granada|la
Dishwasher||lavavajillas|el
Crab||jaiba|la
Hoverboard||patineta eléctrica|la
Meat ball||albóndiga|la
Rice Cooker||arrocera|la
Tuba||tuba|la
Calculator||calculadora|la
Papaya||papaya|la
Antelope||antílope|el
Parrot||loro|el
Seal||lobo marino|el
Butterfly||mariposa|la
Dumbbell||mancuerna|la
Donkey||burro|el
Lion||león|el
Urinal||urinario|el
Dolphin||delfín|el
Electric Drill||taladro|el
Hair Dryer|hair drier
Egg tart||tartaleta|la
Jellyfish||medusa|la
Treadmill||trotadora|la
Lighter||encendedor|el
Grapefruit||pomelo|el
Game board||tablero de juego|el
Mop||trapero|el
Radish||rábano|el
Baozi||pan al vapor|el
Target||diana|la
French||corno francés|el
Spring Rolls||arrollado primavera|el
Monkey||mono|el
Rabbit||conejo|el
Pencil Case||estuche|el
Yak||yak|el
Red Cabbage||repollo morado|el
Binoculars||binoculares|los
Asparagus||espárragos|los
Barbell||barra de pesas|la
Scallop||ostión|el
Noddles||fideos|los
Comb||peineta|la
Dumpling||empanadita|la
Oyster||ostra|la
Table Tennis paddle||paleta de ping-pong|la
Cosmetics Brush/Eyeliner Pencil||brocha de maquillaje|la
Chainsaw||motosierra|la
Eraser||goma de borrar|la
Lobster||langosta|la
Durian||durián|el
Okra||okra|la
Lipstick||lápiz labial|el
Cosmetics Mirror||espejo de maquillaje|el
Curling||piedra de curling|la
Table Tennis||pelota de ping-pong|la
"""

orden = (Path(__file__).parent / 'clases_obj365.txt').read_text(encoding='utf8').split('\n')
orden = [o for o in orden if o]

coco_dart = (RAIZ / 'lib/models/clases_coco.dart').read_text(encoding='utf8')
claves_coco = set(re.findall(r"^\s*'([^']+)':\s*NombreClase", coco_dart, re.M))

filas = [f.split('|') for f in TABLA.strip().split('\n')]
assert [f[0] for f in filas] == orden, 'La TABLA no sigue el orden del modelo'

claves, nombres = [], {}
for f in filas:
    origen, clave = f[0], f[1]
    if clave:
        assert clave in claves_coco, f'{clave} no es una clase COCO'
        claves.append(clave)
        continue
    clave = origen.lower()
    assert len(f) == 4 and f[3] in ('el', 'la', 'los', 'las'), f'Fila incompleta: {f}'
    assert clave not in claves_coco and clave not in nombres, f'Clave repetida: {clave}'
    claves.append(clave)
    nombres[clave] = (f[2], f[3])

faltan = sorted(claves_coco - set(claves))

for c in CLASES_NUEVAS:
    assert c['clave'] not in claves and c['clave'] not in claves_coco, f"Clave repetida: {c['clave']}"
    assert c['articulo'] in ('el', 'la', 'los', 'las'), c


def lit(s):
    return "'" + s.replace("'", "\\'") + "'"


lineas = [
    '// ARCHIVO GENERADO por herramientas/modelos/generar_clases_obj365.py.',
    '// No editar a mano: cambia la tabla del script y vuelve a ejecutarlo.',
    '',
    "import 'clases_coco.dart';",
    '',
    '/// Las 365 clases del modelo D-FINE Objects365, en el ORDEN en que las numera.',
    '/// Las que también existen en COCO usan la misma clave (ej. \'person\').',
    'const List<String> clasesObj365 = [',
    *[f'  {lit(c)},' for c in claves],
    '];',
    '',
    '/// Nombre en español de las clases de Objects365 que no están en COCO.',
    'const Map<String, NombreClase> nombresObj365 = {',
    *[f'  {lit(c)}: NombreClase({lit(n)}, {lit(a)}),' for c, (n, a) in nombres.items()],
    '};',
    '',
    f'// Clases COCO que este modelo NO conoce: {", ".join(faltan) or "ninguna"}.',
    '',
    '/// Clases del modelo PROPIO de Lumina (herramientas/entrenamiento/): las 365 de',
    '/// Objects365 y, a continuación, las nuevas de clases_lumina.py, en ese orden.',
    'const List<String> clasesLumina = [',
    '  ...clasesObj365,',
    *[f"  {lit(c['clave'])}," for c in CLASES_NUEVAS],
    '];',
    '',
    '/// Nombre en español de las clases propias de Lumina.',
    'const Map<String, NombreClase> nombresLumina = {',
    *[f"  {lit(c['clave'])}: NombreClase({lit(c['nombre'])}, {lit(c['articulo'])})," for c in CLASES_NUEVAS],
    '};',
    '',
]
destino = RAIZ / 'lib/models/clases_obj365.dart'
destino.write_text('\n'.join(lineas), encoding='utf8')
print(f'Listo: {destino} ({len(claves)} clases, {len(nombres)} nuevas; '
      f'COCO que faltan: {faltan}; propias de Lumina: {len(CLASES_NUEVAS)})')
