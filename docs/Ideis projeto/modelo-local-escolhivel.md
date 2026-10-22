# Modelo local escolhível (LM Studio)

Issue #121. O resumo do Echo e o parágrafo do Track saíam só do modelo do
Apple Intelligence (`FoundationModels`). Agora a pessoa pode escolher, na tela
do aplicativo, um modelo que já tenha baixado no **LM Studio** — o primeiro
testado é o Qwen3.5 4B (`qwen3.5-4b-mlx`).

## Por quê

| | Apple Intelligence (macOS 26) | Qwen3.5 4B (LM Studio) |
|---|---|---|
| Quanto lê de uma vez | 4.096 tokens | 32.768 tokens (o que pedimos no `load`) |
| Instalação | vem no sistema | a pessoa instala o LM Studio e baixa o modelo |
| Memória | não ocupa quando ninguém usa | ~3 GB, só enquanto resume |
| Sistema mínimo | macOS 26 com Apple Intelligence | macOS 14 em Apple Silicon |

Com 32k, uma reunião de uma hora (~12–15 mil tokens em português) cabe num
bloco só, e o resumo deixa de ser um resumo de resumos, que é onde ele perdia
detalhe. O `SummaryChunker.maxCharsFor(contextTokens)` já escalava com a
janela; o que mudou é que a janela vem da sessão aberta.

## Decisões

- **O padrão continua o Apple Intelligence**, e ele não muda nada: o
  `AppleLocalModel` é o canal do Echo de antes. As chaves
  `app.local_model_source`, `app.local_model_id` e `app.local_model_name` só
  existem com o LM Studio escolhido.
- **Um portão por aplicativo, na janela 0** (`LocalModelGate`). O Echo resume na
  janela 0 e o Track pede do Hub; dois portões descarregariam o modelo um de
  baixo do outro. Um pedido por vez, uma carga para a fila inteira, descarga
  quando ela esvazia.
- **Só descarrega o que carregou.** Se o modelo já estava na memória (a pessoa
  abriu à mão no LM Studio), o Evergreen usa aquela instância, com o contexto
  dela, e não a fecha.
- **API nativa, não a compatível com a OpenAI**: só a nativa deixa escolher o
  contexto no `load` e descarregar quando se quer. `reasoning: "off"` só vai
  quando o modelo o lista em `capabilities.reasoning.allowed_options` (mandar
  para quem não raciocina é erro), e qualquer `<think>` que vaze é limpo.
- **O `load` nativo não aceita `ttl`.** A documentação só dá prazo de
  inatividade a modelo carregado sob demanda. A rede de segurança contra o
  Evergreen cair no meio é outra: ele anota a instância que carregou
  (`app.local_model_loaded_instance`) e a abertura seguinte da janela 0 a
  descarrega (`LmStudioLocalModel.sweep`).
- **Preso a `127.0.0.1:1234`, sem campo de endereço.** O que passa por ali é a
  transcrição de uma reunião.
- **O servidor nunca é ligado sozinho.** "Ligar" roda `~/.lmstudio/bin/lms
  server start`, e só no clique. Quem quer usar sem abrir o LM Studio liga nele
  a opção que sobe o servidor com o login — o servidor é leve e não carrega
  modelo nenhum sozinho.
- **Falha calada, sem volta ao Apple Intelligence.** Servidor desligado, modelo
  apagado ou prazo esgotado se comportam como o `unsupported_os`: o Track
  perde o parágrafo, o "Resumir" do Echo mostra o erro. Um texto escrito por
  outro modelo sem aviso confundiria quem escolheu o Qwen.
- **Cancelar interrompe.** Com o LM Studio, desistir do resumo fecha a conexão
  e o bloco em curso para; com o Apple Intelligence continua sendo entre
  blocos.
- **"Resumido por".** O resumo do Echo grava o nome de exibição na hora
  (`summary_model`, migração `echo-summary-model`, que marca os antigos como
  Apple Intelligence); a leitura e a exportação mostram a linha. O Track guarda
  o modelo no cache e põe a escolha na assinatura do dia.
- **A bolinha.** Com o LM Studio escolhido, o Hub pergunta ao servidor de cinco
  em cinco segundos (`/api/v1/models` só lista, não carrega) e o rodapé da
  barra lateral mostra uma bolinha: verde com um modelo na memória, apagada sem
  nenhum. É o que responde "ele saiu da memória depois do resumo?" sem abrir o
  LM Studio.

## Limites

| Limite | Valor |
|---|---|
| Contexto | 32.768, ou o máximo do modelo se for menor |
| Resposta | 1.500 tokens no Echo, 300 no Track |
| Prazo | 3 min para o `load`, 10 min para cada chamada de chat |
| Paralelismo | 1 pedido por vez |

## Fora daqui

- **Ollama.** Cabe no mesmo `LocalModelBackend`: `keep_alive: 0` e `num_ctx`
  são o mesmo ciclo de carregar, gerar e descarregar.
