# Cadastro Star Wars Saga no Auto Updater

Estado: proposta preparada; ainda não enviada nem aprovada pelos mantenedores do catálogo oficial.

O Auto Updater instalado no Firecast consulta https://sdk3.firecast.app/Plugins/plugins.xml. A RPGmeister consta desse catálogo; MestreRPG.StarWarsSagaEdition ainda não consta.

A proposta em catalog-entry.xml usa o RPK estável do repositório fichasRRPG. O GitHub Actions mantém esse arquivo sincronizado com o último RPK aprovado pela compilação e pelos testes. O botão FIRECAST usa apenas o comando público /autoupdater MestreRPG.StarWarsSagaEdition, depois de verificar cadastro, URL, módulo e versão do pacote.

O processo oficial de inclusão exige fork de rrpgfirecast/firecast, inclusão do projeto e pull request avaliado pelos moderadores. O conector disponível nesta sessão não oferece criação de fork; nenhum pull request foi enviado. A proposta não modifica o catálogo local nem o plugin Auto Updater.

Antes do envio, confirmar com os mantenedores se aceitam o endereço externo estável. Se exigirem hospedagem no repositório oficial, incluir o conteúdo público de ../StarWarsSaga/source.zip em Plugins/Sheets/StarWarsSaga e o RPK em output/STARWARS_SAGA.rpk. Nesse caso, futuras versões nativas dependem também da publicação no repositório oficial.

Referência do processo: https://github.com/rrpgfirecast/firecast#como-colaborar-e-adicionar-seus-projetos
