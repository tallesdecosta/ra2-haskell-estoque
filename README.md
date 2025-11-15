# Gerenciamento de Inventário em Haskell

Implementação de um sistema de inventário em Haskell para disciplina de prog. funcional e lógica.

## Informações 

O sistema guarda o estado atual do inventário em `Inventario.dat`e registra todas as operações (sucesso ou falha) em um log de auditoria `Auditoria.log`.

**Grupo:** 
    * `Danton Talles Telles da Costa` https://github.com/tallesdecosta

    * Trabalho foi feito individualmente por mim. :)

---

## Link (Repl.it)

O projeto pode ser executado pelo link abaixo:

https://replit.com/@tallesdecosta/ra2-haskell-estoque

---


## Comandos

Você pode usar os seguintes comandos:

* `add <id> <nome> <qtde> <categoria>`: Adiciona um novo item (falha se o ID já existir).
* `estoque <id> <qtde_mudar>`: Atualiza o estoque. Use valores positivos (ex: `10`) para adicionar e negativos (ex: `-5`) para remover.
* `remover <id> <qtde_remover>`: Remove uma quantidade específica do estoque (ex: `5` para remover 5).
* `listar`: Exibe todos os itens atualmente no inventário.
* `relatorio erros`: Exibe todos os logs de operações que falharam.
* `relatorio item <id>`: Exibe todo o histórico de movimentações (sucesso ou falha) de um item específico.
* `relatorio mais_movimentado`: Exibe o ID do item com mais operações de sucesso registradas.
* `sair`: Salva o estado e encerra o programa.

---

## 🧪 Validação e Cenários de Teste Manuais

Abaixo está a documentação da execução dos cenários de teste manuais obrigatórios.

### Cenário 1: Persistência de Estado (Sucesso) 

Este cenário testa se o estado é salvo e recarregado corretamente.

1.  **Início (sem arquivos):** O programa é iniciado no Repl.it sem os arquivos `Inventario.dat` ou `Auditoria.log`. O sistema detecta a ausência e inicia com estado vazio.
    ```
    Carregando Inventario.dat...
    Aviso: Arquivo 'Inventario.dat' nao encontrado. Iniciando com dados padrao.
    Carregando Auditoria.log...
    Aviso: Arquivo 'Auditoria.log' nao encontrado. Iniciando com dados padrao.
    Estado carregado.
    ```
2.  **Adição de 3 Itens**:
    ```
    Seu comando > add 001 mouse 50 periferico
    SUCESSO: Operacao registrada.

    Seu comando > add 002 monitor 20 monitor
    SUCESSO: Operacao registrada.

    Seu comando > add 003 cabo-hdmi 100 cabo
    SUCESSO: Operacao registrada.
    ```
3.  **Fechamento:** O programa é fechado com `sair`. Os arquivos `Inventario.dat` e `Auditoria.log` são criados no Repl.it[cite: 69, 70].
    ```
    Seu comando > sair
    Salvando e saindo...
    --- Encerrando. ---
    ```
4.  **Reinício e Verificação:** O programa é iniciado novamente (`Run`). Desta vez, ele carrega os arquivos.
    ```
    Carregando Inventario.dat...
    Carregando Auditoria.log...
    Estado carregado.
    ```
5.  **Verificação de Estado:** O comando `listar` é executado.
    ```
     listar
    --- Inventario Atual ---
    Item {itemID = "001", nome = "mouse", quantidade = 50, categoria = "periferico"}
    Item {itemID = "002", nome = "monitor", quantidade = 20, categoria = "monitor"}
    Item {itemID = "003", nome = "cabo-hdmi", quantidade = 100, categoria = "cabo"}
    ```
O cenário foi concluído com sucesso. O estado foi persistido e recarregado.

### Cenário 2: Erro de Lógica (Estoque Insuficiente)

Este cenário testa o tratamento de uma falha de lógica de negócio.

1.  **Adição de Item:**
    ```
    add 101 teclado 10 periferico
    SUCESSO: Operacao registrada.
    ```
2.  [cite_start]**Tentativa de Remoção (Falha):** Tentativa de remover 15 unidades de um item que só possui 10[cite: 75].
    ```
    removeltem 101 15
    FALHA: ERRO AO ATUALIZAR ESTOQUE: Não há estoque suficiente para realizar essa movimentação. :(
    ```
3.  **Verificação de Estado:** O comando `listar` mostra que o estoque do item "101" não foi alterado (ainda é 10)[cite: 77].
    ```
    listar
    --- Inventario Atual ---
    ...
    Item {itemID = "101", nome = "teclado", quantidade = 10, categoria = "periferico"}
    ...
    ```

O erro foi tratado corretamente. O estado do inventário não foi modificado e o `Auditoria.log` registrou a falha.

### Cenário 3: Geração de Relatório de Erros 

Este cenário testa se a falha do Cenário 2 foi corretamente registrada e pode ser recuperada.

1.  **Execução do Relatório:** Após a falha do Cenário 2, o comando de relatório de erros é executado.
    ```
    relatorio erros
    --- Relatorio de Erros ---
    LogEntry {timestamp = 2025-11-14 23:58:10.12345 UTC, acao = Remove, detalhes = "removeltem 101 15", status = Falha "ERRO AO ATUALIZAR ESTOQUE: Não há estoque suficiente para realizar essa movimentação. :("}
    ```
    
O relatório de erros exibiu com sucesso a entrada de log registrada no Cenário 2.
