import 'package:flutter/material.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  static const Color corPadrao = Color.fromRGBO(0, 105, 148, 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        toolbarHeight: 100.0,
        backgroundColor: const Color(0xFFCCCCCC),
        centerTitle: true,
        title: const Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Guia',
                style: TextStyle(
                  color: corPadrao,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'MediAlerta',
                style: TextStyle(
                  color: Color.fromRGBO(85, 170, 85, 1),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: corPadrao,
              size: 42,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Bem-vindo ao MediAlerta'),
            _text(
              'O MediAlerta foi criado para ajudar você a nunca mais esquecer seus medicamentos.\n'
              'Siga este guia para configurar seu smartphone e utilizar o aplicativo corretamente.',
            ),

            const SizedBox(height: 18),
            _divider(),

            // 1. Preparando o Smartphone
            _title('1. Preparando o Smartphone'),
            _text('Para garantir que os alarmes e notificações funcionem corretamente, siga os passos abaixo:'),

            _subtitle('1.1. Ajustar permissões do sistema'),
            _bullet('Abra Configurações do seu smartphone.'),
            _bullet('Toque em Apps.'),
            _bullet('Acesse Permissões → Início automático em segundo plano e ative o MediAlerta.'),

            const SizedBox(height: 8),

            _subtitle('1.2. Configurar permissões do aplicativo'),
            _bullet('Ainda em Apps, toque em Gerenciar Apps.'),
            _bullet('Encontre o app MediAlerta e abra-o.'),
            _bullet('Vá em Permissões do app e ative:'),
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _styledText('• Armazenamento – necessário para salvar os medicamentos cadastrados.'),
                  _styledText('• Câmera – usada para fotografar a embalagem do medicamento.'),
                ],
              ),
            ),
            _bullet('Volte e entre em Outras Permissões → habilite todas.'),
            _bullet('Entre em Notificações → ative todas, incluindo Lembrete de Medicamentos.'),

            const SizedBox(height: 8),
            _textItalic('Essas permissões garantem que o alarme funcione mesmo com a tela desligada.'),

            const SizedBox(height: 18),
            _divider(),

            // 2. Iniciando o Aplicativo
            _title('2. Iniciando o Aplicativo'),
            _bullet('Abra o MediAlerta.'),
            _bullet('Toque em Começar para ser levado à tela Home.'),
            _bullet('Toque no ícone do Menu (canto superior esquerdo da Home) para acessar as funcionalidades.'),

            const SizedBox(height: 18),
            _divider(),

            // 3. Cadastrar Medicamentos
            _title('3. Cadastrar Medicamentos'),
            _text(
              'Muita atenção ao preencher os dados solicitados, pois isso é o coração do app. Nessa tela você irá preencher:',
            ),

            _bullet('Nome do Medicamento → Basta cadastrar o nome.'),
            _bullet(
              'Quantidade → Informe sempre a quantidade total de medicamento que adquiriu, pois o aplicativo irá controlar e avisar quando estiver acabando.',
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: _text(
                'Observação importante: Quando o tipo do medicamento for Gotas, deve-se multiplicar a quantidade em ML por 20. '
                'Exemplo: Se o frasco possui 20ml a quantidade total a ser informada será de 400 que é igual a 20 X 20. '
                'Quando o tipo for xarope, deve-se informar a quantidade de ML que o frasco possui.',
              ),
            ),
            _bullet(
              'Tipo do Medicamento → Aqui você tem os diversos tipos como: Comprimidos, Gotas, Xarope, Pomada/Creme ou Injeção.',
            ),
            _bullet('Dosagem (por dia) → É a quantidade total de medicamento que irá tomar durante o dia.'),
            _bullet('Modo de Usar → Pode ser de 1 a 5 vezes ao dia.'),
            _bullet('Horários → Escolha os horários de cada dose.'),
            _bullet(
              'Uso contínuo → Se selecionado, mesmo quando acabar o estoque o medicamento permanecerá cadastrado, aguardando a reposição.',
            ),
            _bullet(
              'Fotografar a Embalagem → Opcional. Ajuda a identificar na hora de tomar o medicamento.',
            ),
            _bullet('Salvar → Salva os dados do medicamento.'),
            _text(
              'Após clicar em Salvar, aparecerá uma janela com a opção de → cadastrar novo medicamento, '
              '→ ver o medicamento cadastrado ou → voltar à Home.',
            ),

            const SizedBox(height: 18),
            _divider(),

            // 4. Cadastrar Alertas
            _title('4. Cadastrar Alertas'),
            _bullet('Escolha um dos 5 sons disponíveis para notificação.'),
            _bullet('Você pode ouvir cada um antes de salvar.'),
            _bullet('Toque em Salvar para confirmar.'),

            const SizedBox(height: 18),
            _divider(),

            // 5. Lista de Medicamentos
            _title('5. Lista de Medicamentos'),
            _text('Mostra todos os medicamentos cadastrados. Cada item contém:'),
            _subtitle('5.1. Opções disponíveis'),
            _bullet('Alterar → edite qualquer informação, como horários.'),
            _bullet('Repor → quando você comprar mais, informe a nova quantidade para somar ao estoque.'),
            _bullet('Excluir → remove o medicamento.'),

            const SizedBox(height: 18),
            _divider(),

            // 6. Alertas do Dia
            _title('6. Alertas do Dia'),
            _text('Exibe todos os horários e seus respectivos medicamentos.'),
            _subtitle('Quando o alarme tocar, você verá os seguintes botões:'),
            _bullet('Ver → Mostra o medicamento a ser tomado com as seguintes opções:'),
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _styledText('• Tomar → confirma a dose e diminui no estoque.'),
                  _styledText('• Pular → não altera o estoque.'),
                ],
              ),
            ),
            _bullet('Adiar → Adia o alarme por 15 minutos.'),

            const SizedBox(height: 24),
            _divider(),

            const Center(
              child: Text(
                'Pronto!\nSeu MediAlerta está configurado para ajudar você a manter sua saúde em dia.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: corPadrao,
                ),
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  // Widgets auxiliares (conteúdo preservado, apenas estilo ajustado)
  static Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: corPadrao,
          ),
        ),
      );

  static Widget _subtitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: corPadrao,
          ),
        ),
      );

  static Widget _text(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 20, height: 1.4),
        ),
      );

  static Widget _textItalic(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            height: 1.4,
            fontStyle: FontStyle.italic,
          ),
        ),
      );

  static Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  ', style: TextStyle(fontSize: 20)),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 20, height: 1.4),
              ),
            ),
          ],
        ),
      );

  static Widget _styledText(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 20, height: 1.4),
        ),
      );

  static Widget _divider() => const Divider(thickness: 1.2, height: 24);
}
