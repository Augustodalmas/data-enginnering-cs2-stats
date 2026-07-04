from django.urls import include, path

urlpatterns = [
    path("api/", include("cs2api.urls")),
]
