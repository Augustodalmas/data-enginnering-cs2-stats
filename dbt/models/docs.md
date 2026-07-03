{% docs col_match_id %}
Identidade única da partida, derivada da subpasta `evento/fase` e do nome do
arquivo `.dem` (sem o sufixo `-pN` de partes divididas). Ex.:
`iem-cologne-major-2026/final/furia-vs-falcons-m1-mirage`.
{% enddocs %}

{% docs col_arquivo_origem %}
Caminho do arquivo `.dem` de origem daquela linha, relativo a `./demos/`.
Numa partida dividida em partes (`-p1`/`-p2`), cada parte mantém seu próprio
valor mesmo depois de mescladas em uma única partida.
{% enddocs %}

{% docs col_camada %}
Nome da camada do pipeline que gravou essa versão da linha (`bronze`,
`silver` ou `gold`).
{% enddocs %}

{% docs col_carregado_em %}
Timestamp de quando a carga na bronze rodou — igual para todas as linhas de
todas as tabelas de uma mesma execução de `carregar_demo_duckdb.py`.
{% enddocs %}

{% docs col_transformado_em %}
Timestamp de quando a transformação silver (dbt) rodou para essa linha.
{% enddocs %}

{% docs col_gerado_em %}
Timestamp de quando a transformação gold (dbt) rodou para essa linha.
{% enddocs %}

{% docs col_tick %}
Tick do servidor em que o evento ocorreu — contador incremental do servidor,
não é tempo em segundos (ver `segundos_desde_inicio_round`, quando
disponível na tabela, para o tempo já convertido).
{% enddocs %}

{% docs col_round_num %}
Número do round dentro da partida, já normalizado entre partes divididas
(`-p1`/`-p2`) para formar uma sequência contínua da partida inteira — não
reinicia por arquivo `.dem`.
{% enddocs %}

{% docs col_segundos_desde_inicio_round %}
Segundos decorridos desde o início do round (tick `start` de
`silver.rounds`, que inclui o freeze time) até esse evento, calculado com a
taxa de tick real da partida. Usa o mesmo ponto de referência (`start`) que
`rounds.duracao_segundos`, então os dois são diretamente comparáveis (ex.:
`segundos_desde_inicio_round / duracao_segundos` dá a fração do round em que
o evento ocorreu).
{% enddocs %}

{% docs col_weapon %}
Nome da arma envolvida no evento.
{% enddocs %}

{% docs col_ct_side %}
Valor fixo retornado pelo parser para o lado CT (sempre `"ct"`) — não indica
o nome do time, que troca de lado ao longo da partida. Não usar para
identificar o time real (usar `steamid`).
{% enddocs %}

{% docs col_t_side %}
Valor fixo retornado pelo parser para o lado T (sempre `"t"`) — não indica o
nome do time, que troca de lado ao longo da partida. Não usar para
identificar o time real (usar `steamid`).
{% enddocs %}

{% docs col_participante_nome %}
Nome do jogador nesse papel do evento (atacante, vítima, quem deu
assistência, quem atirou ou quem lançou — depende do prefixo da coluna).
{% enddocs %}

{% docs col_participante_steamid %}
SteamID64 do jogador nesse papel do evento (ver prefixo da coluna).
{% enddocs %}

{% docs col_participante_side %}
Lado (`"t"`/`"ct"`) do jogador nesse papel do evento, no momento em que
ocorreu.
{% enddocs %}

{% docs col_participante_posicao %}
Posição (eixo X, Y ou Z, conforme o sufixo da coluna) do jogador nesse
papel, no momento do evento.
{% enddocs %}

{% docs col_participante_health %}
Vida restante do jogador nesse papel, no momento do evento.
{% enddocs %}

{% docs col_participante_place %}
Callout/área do mapa onde o jogador nesse papel estava no momento do
evento.
{% enddocs %}

{% docs col_evento %}
Nome do campeonato/evento, extraído do primeiro segmento do `match_id`
(estrutura `{evento}/{fase}/{confronto}`).
{% enddocs %}

{% docs col_fase %}
Fase do campeonato (ex.: `semi-final`, `final`), extraída do segundo
segmento do `match_id`.
{% enddocs %}

{% docs col_mapa %}
Nome do mapa jogado (ex.: `de_mirage`), obtido de `silver.header.map_name`
(mapa real parseado da demo) — não extraído do texto do `match_id`, que
mistura time e número da série sem separador confiável.
{% enddocs %}

{% docs col_gold_steamid %}
SteamID64 do jogador — grão da tabela é jogador × partida (ou jogador ×
partida × dimensão extra, conforme o model).
{% enddocs %}

{% docs col_gold_nome %}
Nome do jogador (`ANY_VALUE` entre as linhas da silver — o mesmo jogador
pode ter variações de nome ao longo da partida, ex. tag de clã).
{% enddocs %}
