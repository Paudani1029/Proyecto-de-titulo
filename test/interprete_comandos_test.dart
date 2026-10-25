import 'package:flutter_test/flutter_test.dart';

import 'package:lumina/logica/interprete_comandos.dart';

void main() {
  // (frase, tipo esperado, clase esperada, objeto pedido esperado)
  final casos = <(String, TipoComando, String?, String?)>[
    ('Lumina, ¿qué tengo en frente?', TipoComando.queHayEnfrente, null, null),
    ('lumi que tengo enfrente', TipoComando.queHayEnfrente, null, null),
    ('¿Qué hay delante de mí?', TipoComando.queHayEnfrente, null, null),
    ('describe lo que ves', TipoComando.queHayEnfrente, null, null),
    ('Lumina ¿puedes decirme dónde está mi botella?', TipoComando.dondeEsta, 'bottle', 'botella'),
    ('¿dónde está el celular?', TipoComando.dondeEsta, 'cell phone', 'celular'),
    ('busca una silla', TipoComando.dondeEsta, 'chair', 'silla'),
    ('encuéntrame el control remoto', TipoComando.dondeEsta, 'remote', 'control remoto'),
    ('dónde están las tijeras', TipoComando.dondeEsta, 'scissors', 'tijeras'),
    ('dónde está la botella de agua', TipoComando.dondeEsta, 'bottle', 'botella agua'),
    ('dónde está mi billetera', TipoComando.dondeEsta, null, 'billetera'),
    ('dónde está', TipoComando.dondeEsta, null, null),
    ('Lumina guía mi camino', TipoComando.guiarCamino, null, null),
    ('guíame', TipoComando.guiarCamino, null, null),
    ('ayúdame a caminar', TipoComando.guiarCamino, null, null),
    ('llévame a la farmacia', TipoComando.irADestino, null, null),
    ('guíame a la farmacia', TipoComando.irADestino, null, null),
    ('para', TipoComando.detenerGuia, null, null),
    ('lumina detente', TipoComando.detenerGuia, null, null),
    ('silencio', TipoComando.detenerGuia, null, null),
    ('repite', TipoComando.repetir, null, null),
    ('dímelo otra vez', TipoComando.repetir, null, null),
    ('ayuda', TipoComando.ayuda, null, null),
    ('qué puedes hacer', TipoComando.ayuda, null, null),
    ('lumina', TipoComando.desconocido, null, null),
    ('qué lindo día', TipoComando.desconocido, null, null),
    ('¿dónde estoy?', TipoComando.desconocido, null, null),
    ('quiero un helado para comer', TipoComando.desconocido, null, null),
  ];

  group('interpretarComando', () {
    for (final (frase, tipo, clase, objeto) in casos) {
      test('"$frase"', () {
        final c = interpretarComando(frase);
        expect(c.tipo, tipo);
        expect(c.clase, clase);
        expect(c.objetoPedido, objeto);
      });
    }
  });
}
