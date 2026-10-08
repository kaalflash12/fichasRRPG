# fichasRRPG

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
