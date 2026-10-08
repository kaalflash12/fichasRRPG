# fichasRRPG

## Star Wars Saga — 7.3.4

[RPK da ficha](releases/STARWARS_SAGA_7.3.4.rpk) · [Código-fonte](StarWarsSaga/source.zip) · [Validação da compilação](releases/STARWARS_SAGA_7.3.4_VALIDACAO.json) · [Teste nativo do atualizador](releases/STARWARS_SAGA_7.3.4_TESTE_NATIVO.json)

Esta versão corrige o endereço do botão ATUALIZAR para `kaalflash12/fichasRRPG`. A 7.3.3 usava um repositório que não existia; é necessária uma primeira instalação da 7.3.4 para trocar esse endereço.

O botão consulta `update.txt`, compara versões numéricas, baixa o RPK e valida o identificador do módulo e a versão interna antes de solicitar a instalação ao Firecast. **A instalação automática ainda está bloqueada.** No teste nativo do próprio módulo Star Wars, o manifesto e o RPK foram baixados e validados, mas o SDK respondeu: `Este plug-in não possui autorização para gerenciar plug-ins`. A instalação inicial da 7.3.4 foi concluída pelo RDK oficial. Para as próximas versões serem instaladas pelo botão, o Firecast precisa autorizar o módulo `MestreRPG.StarWarsSagaEdition` a gerenciar plugins. Essa exigência está na [documentação oficial](https://firecast.app/sdk3/BibliotecaFirecastPlugins.html).

### Importar XML da RPGmeister 3.5

Em Geral → IMPORTAR // DATA, selecione o XML exportado pela ficha RPGmeister 3.5. O conversor transfere identidade, atributos, classes, perícias, proezas, talentos, poderes da Força, inventário, perfis de ataque e anotações. Itens fora do catálogo são preservados e informados no relatório. O XML original permanece nos dados da ficha.

O formato RPGmeister 3.5 identifica a estrutura do arquivo; o conversor não transforma regras de D&D 3.5 em regras de Star Wars Saga.

### FX e desempenho

FX mantém o padrão OFF aplicado na 7.3.3 e preserva a escolha posterior do usuário. Os efeitos por componente e as otimizações da versão anterior permanecem.

### Compilação

O workflow Compilar Star Wars Saga usa Windows no GitHub Actions e o instalador oficial do Firecast SDK 3.7b. O canal só é publicado depois que RDK lint, RDK compile, a sintaxe dos arquivos Lua e os testes de lógica do atualizador passam.

Fichas e XMLs privados de personagens não são publicados neste repositório.
