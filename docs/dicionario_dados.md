# Dicionário de Dados — Demos de CS2 (awpy)

Referência do significado de cada coluna nos dataframes gerados pela `awpy`
ao parsear um `.dem`. Valores confirmados rodando contra as demos reais do
projeto (G2 vs Spirit), não só pela documentação da lib.

**Nota sobre tipos**: os tipos mencionados abaixo (inteiro, float, bool...)
são os tipos **lógicos/de domínio** de cada coluna — o que ela representa
conceitualmente. Na camada `bronze` (`output/cs2.duckdb`, schema `bronze`),
**todas as colunas são gravadas como `VARCHAR`**, sem nenhum cast — ver
"Arquitetura de camadas" no `CLAUDE.md`. A camada `silver` (schema `silver`,
populada pelos models dbt em `dbt/models/silver/`) já faz esse cast pro tipo
DuckDB correspondente (`VARCHAR`, `INTEGER`, `BIGINT`/`UBIGINT`, `DOUBLE`,
`BOOLEAN`, `TIMESTAMP`) — o mapeamento coluna → tipo e a descrição de cada
coluna também estão em `dbt/models/silver/_silver__models.yml` (visível no
catálogo `dbt docs`), casado contra este dicionário. Esse dicionário
continua sendo a referência narrativa do tipo lógico/conceitual de cada
coluna.

---

## `header` (dicionário, não é tabela)

| Campo | Significado |
|---|---|
| `map_name` | Nome do mapa (ex.: `de_mirage`) |
| `server_name` | Nome do servidor que gerou a demo |
| `client_name` | Tipo de gravação (ex.: `SourceTV Demo` = demo de GOTV/broadcast) |
| `demo_version_name` / `demo_version_guid` | Versão do formato da demo |
| `patch_version` | Versão do patch do jogo no momento da partida |
| `game_directory` | Caminho do servidor que gerou a demo (informação do ambiente, não do jogo) |
| `demo_file_stamp` | Assinatura interna do arquivo |
| `fullpackets_version`, `allow_clientside_entities`, `allow_clientside_particles`, `addons` | Metadados técnicos de baixo nível, normalmente sem uso analítico |

---

## `rounds` — 1 linha por round

| Coluna | Significado |
|---|---|
| `round_num` | Número do round **dentro desse arquivo .dem** (reinicia em 1 se a partida estiver dividida em vários arquivos — ver seção de demos divididas no `CLAUDE.md`) |
| `start` | Tick em que o round começou |
| `freeze_end` | Tick em que o freeze time (tempo de compra) terminou |
| `end` | Tick em que o round foi decidido (kill final, bomba explodiu, tempo esgotou, etc.) |
| `official_end` | Tick em que o round foi oficialmente encerrado pelo servidor (pode incluir alguns ticks extras após `end`, ex.: tempo de exibição do resultado) |
| `winner` | Lado vencedor: `"t"` ou `"ct"` (lado, **não** nome do time — times trocam de lado) |
| `reason` | Motivo do fim do round: `ct_killed`, `t_killed`, `bomb_exploded`, `bomb_defused`, `time_ran_out` |
| `bomb_plant` | Tick em que a bomba foi plantada nesse round (`NaN` se não foi plantada) |
| `bomb_site` | Local do plant: `bombsite_a`, `bombsite_b`, ou `not_planted` |
| `duracao_segundos` | **Coluna derivada, adicionada na silver** (`dbt/models/silver/silver_rounds.sql`): `(end - start) / taxa_de_tick`. Atenção ao outlier do round pós-troca-de-lado (ver `CLAUDE.md`) |

---

## `kills` — 1 linha por abate

**Na silver**, exclui eventos de reinício de round/pausa técnica (2+
jogadores "matando a si mesmos" com `weapon = 'world'` no mesmo tick —
artefato do servidor, não morte de jogo real; achado validado contra a
HLTV, ver `CLAUDE.md`). Ainda inclui team-kills como linha normal — a
decisão de excluir da métrica "kills" é da camada gold, não da silver.

| Coluna | Significado |
|---|---|
| `tick` | Tick em que o abate ocorreu |
| `round_num` | Round em que ocorreu |
| `segundos_desde_inicio_round` | **Coluna derivada, adicionada na silver**: segundos desde o tick `start` do round (mesma referência de `rounds.duracao_segundos`, os dois são comparáveis) |
| `attacker_*` (`name`, `steamid`, `side`, `X`/`Y`/`Z`, `health`, `place`) | Quem deu o abate: nome, steamid, lado (`t`/`ct`), posição no momento do tiro, vida restante, callout do mapa onde estava |
| `victim_*` (mesmos campos) | Quem morreu |
| `assister_*` (mesmos campos) | Quem deu assistência (campos vazios/`NaN` se não houve assistência) |
| `assistedflash` | `True` se a assistência foi via flashbang (assister cegou a vítima) |
| `weapon` | Arma usada no abate |
| `weapon_itemid` / `weapon_fauxitemid` | IDs internos do item/skin da arma (rastreamento de economia, raramente necessário em análise) |
| `weapon_originalowner_xuid` | Steamid do dono original da arma (relevante quando a arma foi pega de outro jogador morto). **Sempre `NULL` nos dados atuais** — confirmado 0/2.792 kills preenchidos nas 19 partidas carregadas (2 eventos), não é ausência de pickup: o awpy (2.0.2) parece não popular esse campo em nenhum caso. Não usar essa coluna pra identificar arma pega de outro jogador até isso mudar numa versão futura do awpy |
| `headshot` | `True` se foi headshot |
| `hitgroup` | Parte do corpo atingida no tiro fatal: `head`, `chest`, `stomach`, `left_arm`, `right_arm`, `left_leg`, `right_leg`, `neck`, `generic` (`-1` quando não aplicável, ex.: morte por bomba/queda) — lista validada contra os dados reais das 8 demos carregadas |
| `distance` | Distância entre atacante e vítima no momento do abate |
| `dmg_armor` / `dmg_health` | Dano causado à armadura / vida no tiro fatal |
| `penetrated` | Quantas superfícies (parede, etc.) o tiro atravessou antes de acertar (valores observados: 0, 1, 2) |
| `noscope` | `True` se foi um abate com sniper **sem** estar mirando (scope) |
| `thrusmoke` | `True` se o tiro atravessou fumaça |
| `attackerblind` | `True` se o atacante estava cego (flashado) no momento do tiro |
| `attackerinair` | `True` se o atacante estava no ar (saltando) no momento do tiro |
| `noreplay` | Flag interna de elegibilidade pra replay/highlight (raramente útil em análise) |
| `dominated` | `True` quando esse abate gera "domination" (3+ abates seguidos sem o atacante morrer pra essa vítima na partida) — **observado sempre 0 nas nossas demos até agora**, mas a coluna existe |
| `revenge` | `True` quando esse abate é uma "vingança" (vítima havia matado o atacante antes na partida) — **observado sempre 0 nas nossas demos até agora** |
| `wipe` | Contador de quantos abates seguidos o atacante fez nesse round sem morrer (acumula até um "ace") — **observado sempre 0 nas nossas demos até agora** |
| `ct_side` / `t_side` | **Sempre vêm como `"ct"`/`"t"` fixos** — não indicam o nome do time. Não usar pra identificar time real (usar steamid, ver `CLAUDE.md`) |

---

## `damages` — 1 linha por evento de dano (inclui dano que não mata)

| Coluna | Significado |
|---|---|
| `tick`, `round_num` | Quando ocorreu |
| `segundos_desde_inicio_round` | **Coluna derivada, adicionada na silver**: segundos desde o tick `start` do round |
| `attacker_*` / `victim_*` | Mesma lógica de `kills` (quem causou e quem recebeu o dano) |
| `weapon` | Arma usada |
| `hitgroup` | Parte do corpo atingida |
| `armor` / `health` | Armadura / vida **restante** da vítima após o dano |
| `dmg_armor` / `dmg_health` | Dano bruto causado à armadura / vida nesse evento |
| `dmg_health_real` | Dano efetivo de vida (limitado pela vida que a vítima ainda tinha — evita "dano fantasma" maior que a vida restante) |
| `ct_side` / `t_side` | Mesmo caso de `kills`: valores fixos, não confiável pra time real |

---

## `grenades` — 1 linha por **tick** de vida de uma granada (não 1 por lançamento)

| Coluna | Significado |
|---|---|
| `entity_id` | Identificador único da granada em campo — agrupar por esse campo pra reconstruir a trajetória completa de uma granada específica |
| `thrower_steamid` / `thrower` | Quem lançou |
| `grenade_type` | Tipo: `CHEGrenade`/`CHEGrenadeProjectile` (HE), `CFlashbang`/`CFlashbangProjectile` (flash), `CSmokeGrenade`/`CSmokeGrenadeProjectile` (smoke), `CMolotovGrenade`/`CMolotovProjectile` (molotov), `CIncendiaryGrenade` (incendiária), `CDecoyGrenade`/`CDecoyProjectile` (decoy). Os pares "Grenade"/"Projectile" representam fases diferentes (granada na mão vs. já lançada em voo). **Na bronze** também apareceram `CKnife`/`CWeaponGlock` — artefato de parsing do awpy (confirmado numa única partida/round, 1 entidade cada), filtrado na silver (`silver_grenades.sql`), não são granadas de verdade |
| `tick` | Tick daquele instante de vida da granada |
| `X` / `Y` / `Z` | Posição da granada naquele tick. **Padrão de nulo é determinístico, não aleatório**: sempre `NaN` na fase "na mão" (`grenade_type` sem sufixo `Projectile`) e sempre populado na fase "em voo" (sufixo `Projectile`) — confirmado varrendo todas as ~20M linhas da silver, não é só "primeiros ticks" |
| `round_num` | Round em que ocorreu |

---

## `shots` — 1 linha por disparo

| Coluna | Significado |
|---|---|
| `tick`, `round_num` | Quando ocorreu |
| `segundos_desde_inicio_round` | **Coluna derivada, adicionada na silver**: segundos desde o tick `start` do round |
| `player_*` (`name`, `steamid`, `side`, `X`/`Y`/`Z`, `health`, `place`) | Quem disparou e seu estado/posição no momento |
| `weapon` | Arma disparada |
| `silenced` | `True` se a arma estava com silenciador equipado |
| `ct_side` / `t_side` | Mesmo caso acima: valores fixos |

---

## `bomb` — 1 linha por evento da bomba

| Coluna | Significado |
|---|---|
| `tick`, `round_num` | Quando ocorreu |
| `segundos_desde_inicio_round` | **Coluna derivada, adicionada na silver**: segundos desde o tick `start` do round |
| `event` | Tipo do evento: `pickup` (pegou a bomba), `drop` (largou), `plant` (plantou), `defuse` (defusou), `detonate` (explodiu). **Correção**: uma versão anterior desta doc dizia que `defuse` não aparecia — confirmado nos dados reais (awpy 2.0.2) que aparece, com `steamid` de quem defusou. `gold.bomba_jogador_partida` ainda não usa isso (ver "Próximos passos" no `CLAUDE.md`) |
| `X` / `Y` / `Z` | Posição da bomba no evento |
| `steamid` / `name` | Jogador envolvido no evento |
| `bombsite` | Site relacionado (`BombsiteA`/`BombsiteB`, PascalCase), quando aplicável — `NULL` em eventos sem site (pickup/drop/detonate). **Atenção**: grafia diferente de `rounds.bomb_site` (`bombsite_a`/`bombsite_b`, snake_case) — mesmo conceito, casing diferente entre as duas colunas |

---

## `ticks` — 1 linha por jogador por tick capturado (dataframe maior)

| Coluna | Significado |
|---|---|
| `tick` | Tick do servidor naquele instante (ver `CLAUDE.md` pra conversão em segundos) |
| `round_num` | Round em que esse tick ocorreu |
| `segundos_desde_inicio_round` | **Coluna derivada, adicionada na silver**: segundos desde o tick `start` do round |
| `steamid` / `name` | Jogador |
| `side` | Lado nesse tick: `t` ou `ct` |
| `health` | Vida do jogador nesse instante |
| `place` | Callout do mapa onde o jogador estava |
| `X` / `Y` / `Z` | Posição do jogador nesse instante |

---

## `cvars` (a partir de `dem.server_cvars`) — 1 linha por cvar reportada

| Coluna | Significado |
|---|---|
| `name` | Nome da configuração do servidor (cvar), ex.: `mp_freezetime`, `mp_friendlyfire`, `mp_forcecamera`, `tv_transmitall` |
| `tick` | Tick em que aquele valor foi reportado. `-1` é um valor sentinela — cvar reportada antes da gravação começar (sem tick associado) |
| `value` | Valor da cvar naquele momento (sempre string — pode representar número, `true`/`false`, etc., dependendo da cvar) |

- O servidor repete a emissão das mesmas cvars periodicamente durante a
  demo (por isso a mesma `name` aparece centenas de vezes, normalmente com
  o mesmo `value`).
- `mp_freezetime` é a usada pela macro dbt `taxa_de_tick_por_partida()`
  (`dbt/macros/taxa_de_tick_por_partida.sql`) pra calcular a taxa real de
  tick da demo — ver `CLAUDE.md`. Equivalente em Python:
  `detectar_taxa_de_tick` (`ingestion/cs2_utils.py`), não usada pelo
  pipeline hoje (ver "Utilitários reutilizáveis" no `CLAUDE.md`).

---

## Metadados adicionados pelo pipeline (não vêm do `awpy`)

Colunas presentes em **todas** as tabelas (inclusive `header`), adicionadas
por `ingestion/carregar_demo_duckdb.py` durante a carga — não fazem parte do
que o `awpy` extrai da demo:

| Coluna | Significado |
|---|---|
| `match_id` | Identidade da partida, derivada do caminho do `.dem` (pasta de evento/fase + nome do arquivo sem o sufixo `-pN`). Ver "Arquitetura de camadas" no `CLAUDE.md` |
| `_arquivo_origem` | Caminho do `.dem` de onde aquela linha veio, relativo a `./demos/`. Numa partida dividida em partes (`-p1`/`-p2`), cada parte mantém seu próprio `_arquivo_origem` mesmo depois de mescladas |
| `_camada` | Nome da camada que gravou a linha (hoje sempre `"bronze"`) |
| `_carregado_em` | Timestamp de quando a carga rodou — igual para todas as linhas de todas as tabelas de uma mesma execução do script |
| `_transformado_em` | **Só na silver** (não vem da bronze): timestamp de quando a transformação silver rodou — igual para todas as linhas de todas as tabelas de uma mesma execução do `dbt run` |
| `_gerado_em` | **Só na gold** (não vem da silver): timestamp de quando a geração gold rodou — igual para todas as linhas de todas as tabelas de uma mesma execução do `dbt run` |

---

## Camada gold (`dbt/models/gold/`)

Grão: **1 linha por jogador por partida** (`match_id` + `steamid`, ou
`match_id` + `steamid` + uma dimensão extra quando faz sentido). Tudo
derivado da silver, sem reabrir o `.dem`. Ver "Arquitetura de camadas" no
`CLAUDE.md` para o desenho completo (idempotência, decisões, limitações) e
`dbt/models/gold/_gold__models.yml` pra descrição coluna a coluna.

| Tabela | Grão | Colunas próprias |
|---|---|---|
| `gold.combate_jogador_partida` | match_id, steamid | `nome`, `kills`, `headshots`, `hs_pct`, `mortes`, `assistencias`, `team_kills`, `dano_causado`, `dano_recebido`. `kills`/`headshots` excluem team-kills (fogo amigo não conta como abate, mesmo critério da HLTV — validado campo a campo); `mortes` conta qualquer morte real, inclusive por companheiro. Também exclui um artefato de reinício de round/pausa técnica identificado na silver (ver `CLAUDE.md`) |
| `gold.granadas_jogador_partida` | match_id, steamid, categoria_granada | `nome`, `granadas_lancadas` |
| `gold.posicionamento_jogador_partida` | match_id, steamid, place | `nome`, `qtd_ticks`, `segundos_no_local` |
| `gold.bomba_jogador_partida` | match_id, steamid | `nome`, `plants` (defuses não são atribuídos a um jogador ainda — o dado já existe em `silver.bomb.event = 'defuse'`, falta implementar; ver "Próximos passos" no `CLAUDE.md`) |

`gold.dim_partida` (view): `match_id`, `evento`, `fase` (extraídos do
próprio `match_id`) e `mapa` (de `silver.header.map_name` — mapa real
parseado da demo, não texto do `match_id`).

Views de ranking (sem armazenamento próprio, somam as tabelas acima por
`steamid`), em 4 granularidades por tema:
- Total geral: `gold.ranking_kills`, `gold.ranking_granadas`, `gold.ranking_tempo_por_local`
- Por fase (semi-final, final, ...) dentro do evento: `gold.ranking_kills_por_fase`, `gold.ranking_granadas_por_fase`, `gold.ranking_tempo_por_local_por_fase`
- Por campeonato inteiro (soma todas as fases): `gold.ranking_kills_por_evento`, `gold.ranking_granadas_por_evento`, `gold.ranking_tempo_por_local_por_evento`
- Por mapa, cruzando evento/fase (ex.: "fulano é melhor em qual mapa"): `gold.ranking_kills_por_mapa`, `gold.ranking_granadas_por_mapa`, `gold.ranking_tempo_por_local_por_mapa` (esta última agrupa por `mapa` + `place`, já que o mesmo callout existe em mapas diferentes)

`gold.ranking_team_kills` (só total geral, sem variantes por fase/evento/mapa
ainda): total de fogo amigo por jogador. Diferente das demais views de
ranking, só lista quem tem pelo menos 1 team-kill.

`hs_pct` = `headshots / kills` (`NULL` quando `kills = 0`, não `0` — "sem
kills" é diferente de "0% de headshot").
`dano_causado`/`dano_recebido` usam `dmg_health_real` de `silver.damages`
(dano efetivo, já limitado pela vida restante da vítima), não `dmg_health`
(dano bruto).

---

## Padrão de nomenclatura

- Prefixos `attacker_`, `victim_`, `assister_`, `player_`, `thrower_` sempre
  indicam "de qual pessoa envolvida no evento" aquele campo fala — os
  sufixos depois do prefixo (`_name`, `_steamid`, `_side`, `_X/Y/Z`,
  `_health`, `_place`) têm o mesmo significado em qualquer dataframe.
- `*_place` = callout/área do mapa (nome dado pelo level design, ex.:
  `BombsiteB`, `Connector`). Não confundir com `bombsite` (que é
  especificamente `bombsite_a`/`bombsite_b`).
- Datas/tempo sempre vêm como `tick` (inteiro) na bronze. Na silver, as
  tabelas de evento (`rounds`, `kills`, `damages`, `shots`, `bomb`,
  `ticks`) já trazem a conversão pronta (`duracao_segundos` /
  `segundos_desde_inicio_round`, ver seções acima) — conversão manual
  (`ingestion/cs2_utils.py`) só é necessária fora do pipeline dbt.
