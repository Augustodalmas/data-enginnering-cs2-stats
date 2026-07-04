from django.urls import path

from .views_consulta import (
    BombaJogadorPartidaView,
    CombateJogadorPartidaView,
    DimPartidaView,
    GranadasJogadorPartidaView,
    PosicionamentoJogadorPartidaView,
)
from .views_upload import StatusJobView, UploadDemoView

urlpatterns = [
    path("partidas/", DimPartidaView.as_view(), name="partidas"),
    path("combate/", CombateJogadorPartidaView.as_view(), name="combate"),
    path("granadas/", GranadasJogadorPartidaView.as_view(), name="granadas"),
    path("posicionamento/", PosicionamentoJogadorPartidaView.as_view(), name="posicionamento"),
    path("bomba/", BombaJogadorPartidaView.as_view(), name="bomba"),
    path("demos/", UploadDemoView.as_view(), name="upload-demo"),
    path("demos/status/<str:job_id>/", StatusJobView.as_view(), name="status-job"),
]
