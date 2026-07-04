"""
Endpoints de leitura (GET) da camada gold. Ver ConsultaGoldBaseView pro
padrão genérico (paginação + filtro empurrados pro DuckDB, cache Redis) —
cada view concreta só declara qual tabela consultar e quais colunas podem
ser usadas como filtro.
"""

from urllib.parse import urlencode

from django.conf import settings
from django.core.cache import cache
from rest_framework.response import Response
from rest_framework.views import APIView

from .duckdb_consulta import executar_consulta_paginada

TAMANHO_PAGINA_PADRAO = 50
TAMANHO_PAGINA_MAXIMO = 500


class ConsultaGoldBaseView(APIView):
    """
    View genérica de leitura pra uma tabela/view da gold, servida a partir
    do Parquet exportado (nunca do cs2.duckdb — ver duckdb_consulta.py e
    CLAUDE.md). Resultado da página cacheado no Redis por URL completa
    (TTL fixo em settings.CACHE_TTL_SEGUNDOS, sem invalidação ativa —
    decisão registrada no CLAUDE.md).

    Subclasses definem:
      tabela_fato            nome do arquivo parquet (sem extensão)
      com_join_dim_partida    se True, faz JOIN com dim_partida e expõe
                              evento/fase/mapa/confronto_id/formato/
                              time_1/time_2 além das colunas da própria
                              tabela
      colunas_filtro          lista de nomes de coluna aceitos como filtro
                              exato via query param (whitelist)
      coluna_ordenacao        string fixa de ORDER BY (não vem do request)
    """

    tabela_fato = None
    com_join_dim_partida = True
    colunas_filtro = []
    coluna_ordenacao = "match_id"

    def get(self, request):
        chave_cache = f"cs2api:{self.tabela_fato}:{request.get_full_path()}"
        payload_cacheado = cache.get(chave_cache)
        if payload_cacheado is not None:
            return Response(payload_cacheado)

        pagina = self._parametro_inteiro(request, "page", padrao=1, minimo=1)
        tamanho_pagina = self._parametro_inteiro(
            request, "page_size", padrao=TAMANHO_PAGINA_PADRAO,
            minimo=1, maximo=TAMANHO_PAGINA_MAXIMO,
        )

        filtros = {
            coluna: valor
            for coluna, valor in request.query_params.items()
            if coluna in self.colunas_filtro
        }

        total, linhas = executar_consulta_paginada(
            tabela_fato=self.tabela_fato,
            com_join_dim_partida=self.com_join_dim_partida,
            colunas_filtro=self.colunas_filtro,
            filtros=filtros,
            coluna_ordenacao=self.coluna_ordenacao,
            pagina=pagina,
            tamanho_pagina=tamanho_pagina,
        )

        total_paginas = (total + tamanho_pagina - 1) // tamanho_pagina if total else 0
        payload = {
            "count": total,
            "page": pagina,
            "page_size": tamanho_pagina,
            "total_pages": total_paginas,
            "next": self._url_pagina(request, pagina + 1) if pagina < total_paginas else None,
            "previous": self._url_pagina(request, pagina - 1) if pagina > 1 else None,
            "results": linhas,
        }

        cache.set(chave_cache, payload, timeout=settings.CACHE_TTL_SEGUNDOS)
        return Response(payload)

    @staticmethod
    def _parametro_inteiro(request, nome, padrao, minimo, maximo=None):
        try:
            valor = int(request.query_params.get(nome, padrao))
        except (TypeError, ValueError):
            valor = padrao
        valor = max(minimo, valor)
        if maximo is not None:
            valor = min(valor, maximo)
        return valor

    @staticmethod
    def _url_pagina(request, pagina):
        params = request.query_params.copy()
        params["page"] = pagina
        return f"{request.build_absolute_uri(request.path)}?{urlencode(params)}"


class CombateJogadorPartidaView(ConsultaGoldBaseView):
    tabela_fato = "combate_jogador_partida"
    colunas_filtro = ["match_id", "steamid", "evento", "fase", "mapa", "confronto_id"]
    coluna_ordenacao = "kills DESC"


class GranadasJogadorPartidaView(ConsultaGoldBaseView):
    tabela_fato = "granadas_jogador_partida"
    colunas_filtro = [
        "match_id", "steamid", "categoria_granada", "evento", "fase", "mapa", "confronto_id",
    ]
    coluna_ordenacao = "granadas_lancadas DESC"


class PosicionamentoJogadorPartidaView(ConsultaGoldBaseView):
    tabela_fato = "posicionamento_jogador_partida"
    colunas_filtro = ["match_id", "steamid", "place", "evento", "fase", "mapa", "confronto_id"]
    coluna_ordenacao = "segundos_no_local DESC"


class BombaJogadorPartidaView(ConsultaGoldBaseView):
    tabela_fato = "bomba_jogador_partida"
    colunas_filtro = ["match_id", "steamid", "evento", "fase", "mapa", "confronto_id"]
    coluna_ordenacao = "plants DESC"


class DimPartidaView(ConsultaGoldBaseView):
    tabela_fato = "dim_partida"
    com_join_dim_partida = False
    colunas_filtro = [
        "match_id", "evento", "fase", "mapa", "confronto_id", "formato", "time_1", "time_2",
    ]
    coluna_ordenacao = "match_id"
