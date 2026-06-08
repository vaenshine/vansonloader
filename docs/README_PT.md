# VansonLoader

**VansonLoader é a edição dylib do VansonMod. É um pacote runtime derivado que leva fluxos selecionados da VM para um painel flutuante injetado no processo alvo.**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | **Português** | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## Introdução

**VansonMod** é o aplicativo principal para TrollStore. Ele oferece o fluxo autônomo completo: seleção de processo, busca de memória, fluxos avançados de ponteiros, patch RVA, ferramentas de script, gerenciamento de arquivos e configurações.

**VansonLoader** é um produto derivado para ambientes runtime injetados. Ele empacota recursos selecionados da VM como dylib e os expõe por um painel sobreposto dentro do processo alvo.

## Relação Com VansonMod

- **VansonMod** é o aplicativo principal e o ponto principal de release: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader** é a derivação dylib da mesma direção de projeto.
- Dados mod e script exportados pela VM podem ser usados em fluxos runtime compatíveis com o Loader.
- VansonMod permanece como editor completo para fluxos avançados de ponteiros, seleção de apps, gerenciamento de arquivos e configurações globais.

## Escopo Atual

- Painel flutuante e botão de abertura rápida dentro do processo injetado.
- Busca de memória, resultados, navegação de memória e edição de valores.
- Importação e armazenamento de dados VM/VL `.vm` e `.vmsc`.
- Itens pointer importados para exibição de valor, escrita de valor, controles tipo lock e modos de UI por resultado.
- Itens RVA importados para patch e restore em runtime.
- Itens signature importados para scan, exibição de resultados e patch runtime opcional.
- Execução JavaScript com aliases estilo H5GG e APIs de memória VM/VL.
- Watch overlay, inspetor de instruções e caminhos para RVA quando o ambiente runtime oferecer suporte.

## Build

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## Release

VansonLoader tem seu próprio script de release:

```sh
./scripts/release.sh
```

## Aviso

Este projeto é destinado a pesquisa de segurança, aprendizado de engenharia reversa e testes técnicos compatíveis.

Use em ambientes legais e respeite as regras aplicáveis dos apps e sistemas alvo. Riscos operacionais e responsabilidades legais decorrentes do uso pertencem ao usuário.

## Licença

GPL-3.0. Veja [LICENSE](./LICENSE).
