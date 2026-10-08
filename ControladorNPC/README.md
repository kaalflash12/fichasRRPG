# Controlador de NPCs do mestre — Star Wars Saga

Plugin **separado** da ficha do personagem, com RPK e canal de atualização próprios.

Versão **1.0.1**: corrige a abertura do painel e a inicialização após o carregamento da ficha; RECARREGAR também recupera uma instância ainda não iniciada.

Depois de instalar, abra **STARWARS — CONTROLADOR NPC DO MESTRE** nas janelas acopláveis da mesa. O Firecast exige Gold, ou uma mesa cujo criador tenha Gold Plus, para esse tipo de painel. A alternativa incluída no mesmo RPK é criar uma ficha do modelo **STARWARS — CONTROLE DO MESTRE (NPCs)** na Biblioteca e abri-la na mesa. O controlador exige o modo **+mestre** nas duas formas.

## Uso

- Crie ou importe os NPCs na Biblioteca usando **STARWARS-SAGA D/L**. A importação de XML RPGmeister 3.5 é feita pela ficha Star Wars, em **Geral → IMPORTAR // DATA**.
- Clique em **RECARREGAR**, busque o nome e selecione um NPC. O filtro inicial inclui NPCs sem dono e fichas pertencentes ao mestre atual; escolha “Somente NPCs sem dono” para restringir.
- **ABRIR FICHA COMPLETA** abre a ficha existente em outra aba sem forçar foco ou substituir a aba atual.
- Defina PV, retire dano líquido ou recupere PV. Dano líquido significa o valor já descontado de redução de dano e escudos; PV temporários são consumidos primeiro. Morte, estado de derrota e efeitos especiais devem ser resolvidos na ficha completa. O controlador não resolve ataques automaticamente.
- Escolha a condição e clique em **SALVAR CONDIÇÃO**. O resumo do controlador considera a diferença de penalidade, mesmo com a ficha completa fechada. Os demais cálculos da ficha são atualizados pelo próprio modelo ao abrir a ficha completa.
- **DESFAZER** restaura o último ajuste de PV/condição somente se os campos afetados não tiverem mudado desde o ajuste.
- Adicione NPCs ao encontro, informe suas iniciativas e avance turnos/rodadas. Iniciativa e anotações são privadas e persistem neste computador, separadas por mestre e mesa. Não alteram a iniciativa pública nem publicam mensagens.

O controlador lê somente os metadados da biblioteca para montar a lista. Abre o NodeDatabase apenas do NPC selecionado; a lista exibe até 60 registros por página, busca tem atraso de 120 ms e não há animações nem consultas contínuas. Não altera fichas ao instalar ou abrir o painel.

## Atualização

**BAIXAR RPK** abre o arquivo estável no navegador, como a RPGmeister. **FIRECAST** verifica o canal próprio e pode usar o comando público do Auto Updater depois que este plugin estiver cadastrado no catálogo oficial. **O cadastro oficial está pendente; instalar este RPK não libera atualização nativa automática.**

Módulo: `MestreRPG.SWSE.NPCController`. Os tipos de personagem `MestreRPG.SWSE.Character` e de veículo `MestreRPG.SWSE.Vehicle` continuam sendo registrados apenas pelo RPK da ficha Star Wars.
