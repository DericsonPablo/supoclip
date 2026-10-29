# SupoClip local — piloto isolado

Esta configuração usa frontend, backend, worker, PostgreSQL, Redis, Ollama e um gateway Nginx. A interface abre em `http://127.0.0.1:3107/` e a API em `127.0.0.1:8000`; apenas o gateway publica essas duas portas no loopback. Os outros serviços ficam numa rede Docker interna, sem saída direta para a internet. Os volumes Docker guardam mídia e dados. O projeto Compose é `supoclip-pilot`, separado dos outros serviços deste computador.

Código-fonte: [fork público DericsonPablo/supoclip, ramo do piloto](https://github.com/DericsonPablo/supoclip/tree/codex/local-pilot), baseado no projeto de FujiwaraChoki. O aplicativo usa [AGPL-3.0](LICENSE); o modelo [Qwen2.5 7B Instruct](https://ollama.com/library/qwen2.5:7b-instruct) usa Apache 2.0. Consulte essas licenças antes de redistribuir ou oferecer o serviço a terceiros.

O arquivo `.env.local` contém segredos gerados neste computador e é ignorado pelo Git. Não o envie nem o copie para um repositório. O piloto usa Whisper e Ollama locais, sem chaves de serviços de transcrição ou LLM pagos. Publicação social, telemetria e serviços opcionais estão desativados. Um teste com vídeo sintético completou upload, transcrição, seleção de 2 cortes e exportação de MP4 com áudio; o uso com mídia pessoal e a equivalência editorial com o OpusClip ainda não foram validados. A auditoria de segurança do código foi parcial.

## Abrir e usar

Abra `ABRIR-SUPOCLIP-LOCAL.cmd` com duplo clique. A interface fica em `http://127.0.0.1:3107/`. Na primeira visita, crie uma conta local pela tela de cadastro. Envie um vídeo e revise os trechos escolhidos antes de exportar. O processamento usa CPU local e pode levar alguns minutos.

Para conferir os contêineres: `ABRIR-SUPOCLIP-LOCAL.cmd -Status`. Para parar sem apagar os dados: `ABRIR-SUPOCLIP-LOCAL.cmd -Stop`. Os arquivos e contas locais ficam em volumes Docker deste piloto.

## Instalação inicial

Abra PowerShell nesta pasta e use **somente** `docker-compose.pilot.yml`:

```powershell
./CRIAR-CONFIG-LOCAL.ps1
$dc = @('--env-file', '.env.local', '-p', 'supoclip-pilot', '-f', 'docker-compose.pilot.yml')
docker compose @dc config --quiet
docker compose @dc build backend frontend
docker compose @dc up -d --no-build
./PREPARAR-MODELOS-LOCAIS.ps1
docker compose @dc ps
```

`CRIAR-CONFIG-LOCAL.ps1` gera segredos aleatórios independentes e se recusa a substituir `.env.local` existente. Neste computador a configuração já foi criada; para reinstalar os contêineres, mantenha o arquivo atual e comece pelo comando `$dc`.

O download inicial de imagens, dependências e pesos dos modelos requer internet e espaço em disco. `PREPARAR-MODELOS-LOCAIS.ps1` para temporariamente apenas o worker e o Ollama deste projeto, baixa os pesos em contêineres separados com rede padrão e restaura o estado anterior dos serviços. Se o antivírus do Windows interceptar a conexão do Ollama, o script acrescenta temporariamente a CA pública já confiada pelo Windows ao pacote da imagem para verificar TLS; não desativa a verificação. Nenhuma mídia é montada nesses contêineres de download. O menu Iniciar não recebe alterações.

## Uso editorial

Para um vídeo vertical **já composto** com tela acima e apresentador abaixo, selecione **Imagem completa 9:16** (`vertical_fit`) para conservar o quadro. Em uma fonte horizontal, essa opção sozinha não cria a composição editorial dividida. O teste sintético usou uma fonte horizontal e confirmou a exportação funcional; ainda é necessário avaliar uma fonte real já composta e a qualidade dos cortes no seu padrão.

Esta cópia local não altera nem cancela o OpusClip. Não use `start.sh`, `install_cron.sh` ou `docker-compose.yml` para este piloto; esses caminhos têm serviços e configurações diferentes.
