# Painel espacial de acidentes · BR-381 e BR-262 · Betim (MG)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23644596.svg)](https://doi.org/10.5281/zenodo.23644596)

Painel interativo e rotina de análise dos acidentes de trânsito registrados pela Polícia Rodoviária Federal (PRF)
nas rodovias BR-381 e BR-262, no município de Betim (MG), de 2017 a 2025.

**Acesse o painel:** https://gabrielaifmg.github.io/painel-acidentes-betim/painel/

Projeto de pesquisa do IFMG *Campus* Betim (Edital 162/2026).
Equipe: Artur Gonçalves de Jesus (IFMG), Gabriela Oliveira (IFMG) e Bruno Oliveira da Silva (CEFET-MG).

## O que o painel mostra

- **Polos espaciais:** áreas de 500 m que concentram acidentes, sobre imagem aérea, com o perfil de cada polo.
- **Evolução no tempo:** animação mensal do acumulado de acidentes de 2017 a 2025.
- **Rankings espaciais:** os polos com mais acidentes e com maior severidade, e uma matriz de prioridade
  que combina frequência, severidade e persistência ao longo dos anos.

Todos os mapas podem ser filtrados por ano, rodovia, causa, tipo, classificação e severidade do acidente.

## Como citar

JESUS, A. G.; OLIVEIRA, G.; SILVA, B. O. **Painel espacial de acidentes nas rodovias BR-381 e BR-262 em Betim (MG)**:
dados, rotina de análise em R e painel interativo. Betim: IFMG, 2026. Disponível em:
https://gabrielaifmg.github.io/painel-acidentes-betim/painel/. DOI: https://doi.org/10.5281/zenodo.23644596.

## Conteúdo do repositório

```
painel/                       painel interativo (index.html) e base de dados (dados.js)
analise_capitulo_e_painel.R   rotina em R: tabelas, figuras e dados do painel
dados/                        planilhas da PRF, traçado das rodovias (SNV/DNIT) e pontos de referência
resultados/                   tabelas, figuras (300 dpi) e valores citados no capítulo
```

## Como reproduzir a análise

No R, com a pasta do repositório como diretório de trabalho:

```r
source("analise_capitulo_e_painel.R")
```

A rotina regrava as tabelas e as figuras em `resultados/` e a base do painel em `painel/dados.js`.
Para incluir um novo ano, acrescente as planilhas da PRF em `dados/` e ajuste `ANOS` no início do script.

## Dados e limitações

- **Fonte:** PRF, dados abertos de acidentes (agrupados por ocorrência e por pessoa), 2017–2025:
  https://www.gov.br/prf/pt-br/acesso-a-informacao/dados-abertos
- **Traçado das rodovias:** Sistema Nacional de Viação (SNV/DNIT), versão 202308A.
- **Coordenadas:** registros que perderam o separador decimal foram corrigidos; os que permaneceram fora do
  município entram nos totais, mas não no mapa.
- **Óbitos:** a PRF registra apenas os óbitos ocorridos no local do acidente.
- **Frequências:** os valores são contagens de acidentes, e não taxas por volume de tráfego.

## Uso de inteligência artificial

O código do painel e partes da rotina de análise foram desenvolvidos com apoio de ferramentas de inteligência
artificial generativa, sob supervisão e revisão dos autores.

## Licença

Código sob licença MIT (arquivo `LICENSE`). Dados derivados sob CC BY 4.0, com crédito à PRF como fonte original.
