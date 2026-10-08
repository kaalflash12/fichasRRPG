# fichasRRPG

## Controlador NPC do mestre — 1.0.1 (RPK separado)

[RPK do controlador](releases/CONTROLADOR_NPC_STARWARS.rpk) · [RPK 1.0.1](releases/CONTROLADOR_NPC_STARWARS_1.0.1.rpk) · [Como usar](ControladorNPC/README.md) · [Código-fonte](ControladorNPC/source) · [Validação CI](releases/CONTROLADOR_NPC_STARWARS_1.0.1_VALIDACAO.json) · [Teste nativo](releases/CONTROLADOR_NPC_STARWARS_1.0.1_TESTE_NATIVO.json)

Plugin independente da ficha Star Wars. Busca NPCs da mesa, abre fichas completas sem forçar foco, ajusta PV e condição, organiza turnos/rodadas e guarda anotações privadas por mestre e mesa. Inclui painel da mesa e ficha de controle alternativa. O controle de PV usa valores líquidos/manuais; a resolução completa dos ataques permanece na ficha. O cadastro do controlador no Auto Updater oficial também está pendente.

## Star Wars Saga — 7.3.5

[RPK atual](releases/STARWARS_SAGA.rpk) · [RPK 7.3.5](releases/STARWARS_SAGA_7.3.5.rpk) · [Código-fonte](StarWarsSaga/source.zip) · [Validação](releases/STARWARS_SAGA_7.3.5_VALIDACAO.json)

O topo oferece dois caminhos de atualização, seguindo os mecanismos usados pela RPGmeister:

- **BAIXAR RPK:** abre o pacote atual do GitHub no navegador. Abra o arquivo baixado para instalar no Firecast.
- **FIRECAST:** consulta a versão publicada e verifica o cadastro no catálogo oficial. Quando a ficha estiver cadastrada, valida o pacote e solicita a instalação pelo comando público do Auto Updater. A instalação só é indicada como concluída após a versão instalada ser confirmada.

**O cadastro no catálogo oficial ainda está pendente.** A instalação automática do próprio módulo foi recusada pelo SDK na 7.3.4. A 7.3.5 usa o fluxo público do Auto Updater para fichas cadastradas, sem alterar o plugin oficial ou atribuir permissões ao módulo da ficha. Enquanto o cadastro não for aprovado, use BAIXAR RPK.

[Proposta de cadastro](integracao-firecast/README.md) · [Documentação oficial](https://firecast.app/sdk3/BibliotecaFirecastPlugins.html)

### Importar XML RPGmeister 3.5

Em Geral → IMPORTAR // DATA, selecione o XML exportado pela RPGmeister 3.5. O conversor transfere identidade, atributos, classes, perícias, proezas, talentos, poderes da Força, inventário, perfis de ataque e anotações. Itens fora do catálogo são preservados; o XML original permanece nos dados da ficha.

O formato RPGmeister 3.5 identifica a estrutura do arquivo. O conversor não transforma regras de D&D 3.5 em Star Wars Saga.

### FX e desempenho

FX mantém o padrão OFF aplicado na 7.3.3 e preserva a escolha posterior do usuário. As otimizações, os efeitos individuais e a busca por nome da loja permanecem.

### Compilação

O GitHub Actions compila com o RDK oficial no Windows. Publica o pacote, o link estável e o manifesto somente depois que lint, compilação, sintaxe Lua e os 32 testes do atualizador passam.

Fichas e XMLs privados de personagens não são publicados.
