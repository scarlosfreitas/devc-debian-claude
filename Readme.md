# Como utilizar
```bash
git clone https://github.com/scarlosfreitas/devc-debian-claude.git
mv -- devc-debian-claude/{*,.[!.]*,..?*} .
rmdir devc-debian-claude
```
* troca o nome em devcontainer.json
* cria .env com o nome da imagem
* Ctrl+shift+p reopen in container
* loga no claude code no chat e no terminal
* apaga a pasta .git e reinicia (git init)

# Criar uma imagem intermediaria para trabalhar em paralelo
docker compose -f .devcontainer/docker-compose.yml up
