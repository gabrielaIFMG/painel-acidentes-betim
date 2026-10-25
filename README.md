# Painel espacial de acidentes · BR-381 e BR-262 · Betim (MG)

Painel interativo e rotina de análise dos acidentes registrados pela Polícia Rodoviária Federal (PRF)
nas rodovias BR-381 e BR-262, no município de Betim (MG), de 2017 a 2025.

Projeto de pesquisa IFMG *Campus* Betim, Edital 162/2026.
Equipe: Artur Gonçalves de Jesus, Gabriela Oliveira e Bruno Oliveira da Silva.

## Estrutura

```
analise_capitulo_e_painel.R   rotina completa em R (capítulo + dados do painel)
dados/                        planilhas da PRF (acidentesAAAA_por_ocorrencia.xlsx e acidentesAAAA_por_pessoa.xlsx)
resultados/
  tabelas/                    Tabelas 1 a 3 do capítulo (.csv e .xlsx) e tabelas auxiliares
  figuras/                    Figuras 1 a 3 do capítulo (.jpg, 300 dpi)
  numeros_do_texto.txt        todos os valores citados no texto do capítulo
painel/
  index.html                  painel (HTML + JavaScript + Leaflet)
  dados.js                    base do painel, gerada pelo script em R
```

## Como atualizar os dados

1. Coloque as planilhas da PRF na pasta `dados/` (para incluir um novo ano, ajuste `ANOS` no início do script).
2. No R ou RStudio, com a pasta do projeto como diretório de trabalho, execute:
   ```r
   source("analise_capitulo_e_painel.R")
   ```
3. O script regrava as tabelas, as figuras e o arquivo `painel/dados.js`.
   Basta publicar novamente o `dados.js`; o `index.html` não precisa ser alterado.

Para testar o painel localmente, abra `painel/index.html` no navegador (é preciso conexão à internet
para carregar o Leaflet e os mapas de fundo).

## Publicação no GitHub Pages (endereço estável e gratuito)

1. Crie uma conta em https://github.com (de preferência com e-mail institucional).
2. Crie um repositório público, por exemplo `painel-acidentes-betim`.
3. Envie os arquivos deste projeto (botão *Add file → Upload files*). Recomenda-se **não** enviar as planilhas
   brutas da PRF se o repositório ficar pesado; indique o link oficial dos dados abertos.
4. Em *Settings → Pages*, em *Build and deployment*, escolha *Deploy from a branch*, a branch `main` e a pasta
   `/ (root)`. Se preferir publicar só o painel, mova `index.html` e `dados.js` para uma pasta `docs/` e escolha `/docs`.
5. Após alguns minutos, o painel ficará disponível em
   `https://<usuario>.github.io/painel-acidentes-betim/painel/` (ou `/` se usar a pasta `docs`).

## DOI permanente (Zenodo)

1. Entre em https://zenodo.org com a conta do GitHub e ative o repositório em *GitHub → Repositories*.
2. No GitHub, crie uma *release* (por exemplo, `v1.0`). O Zenodo arquiva automaticamente a versão e gera um DOI.
3. Use o DOI para citar o painel e a rotina no capítulo do e-book e no artigo, e atualize a seção
   "Sobre o painel" do `index.html` com o endereço definitivo e o DOI.

## Observações metodológicas

- **Agrupamento:** o painel agrupa as ocorrências apenas pelas coordenadas, em células fixas (padrão: 500 m,
  mínimo de 5 ocorrências por polo), com a alternativa de agrupamento por densidade (DBSCAN).
- **Coordenadas:** registros que perderam o separador decimal foram corrigidos por reescalonamento. Os que
  permaneceram fora do município ficam sem posição: entram nos totais, mas não no mapa, nos polos ou nos rankings.
- **Severidade:** é a maior gravidade observada no acidente. Acidentes sem feridos registrados, mas com
  envolvidos de estado físico ignorado, são classificados como "Indeterminada".
- **Limitações:** os óbitos são registrados apenas no local do acidente, e os valores são frequências,
  não taxas por volume de tráfego.
- **Uso de IA:** o código do painel e partes da rotina de análise foram desenvolvidos com apoio de ferramentas
  de inteligência artificial generativa, sob supervisão e revisão dos autores.

## Licença (sugestão)

Código sob licença MIT; dados derivados sob CC BY 4.0, com crédito à PRF como fonte original.
