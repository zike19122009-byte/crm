# CRM Rematrícula — com login e Supabase

Este pacote tem 3 arquivos:
- `index.html` → o sistema (login/cadastro + quadro Kanban + tabela geral)
- `schema.sql` → o banco de dados (tabelas + permissões)
- este guia

## Passo 1 — Criar o projeto no Supabase
1. Acesse **supabase.com** → crie uma conta → **New Project**.
2. Anote a senha do banco que você definir (não precisa dela no código, mas guarde).
3. Aguarde o projeto terminar de provisionar (1–2 minutos).

## Passo 2 — Rodar o banco de dados
1. No painel do projeto, vá em **SQL Editor** → **New query**.
2. Cole todo o conteúdo do arquivo `schema.sql` e clique em **Run**.
3. Isso cria as 3 tabelas (`profiles`, `contacts`, `notes`), as regras de permissão (RLS) e o gatilho que cria o perfil automaticamente quando alguém se cadastra.

## Passo 3 — Pegar as chaves da API
1. Vá em **Project Settings → API**.
2. Copie a **Project URL** e a **anon public key**.
3. Abra `index.html`, procure por:
   ```js
   var SUPABASE_URL = 'https://SEU-PROJETO.supabase.co';
   var SUPABASE_ANON_KEY = 'SUA_CHAVE_ANON_PUBLICA';
   ```
   e substitua pelos valores do seu projeto.

## Passo 4 — (Recomendado) Desligar a confirmação de e-mail
Como é um sistema interno da equipe, o mais prático é não exigir confirmação de e-mail:
- Vá em **Authentication → Providers → Email** e desative "Confirm email".
- Se preferir manter a confirmação, cada colaborador vai precisar clicar no link que chega por e-mail antes do primeiro login.

## Passo 5 — Abrir o sistema e criar sua conta (administrador)
1. Abra o `index.html` no navegador (pode hospedar em qualquer lugar: GitHub Pages, Netlify, Vercel, ou até localmente).
2. Clique em **Criar conta**, cadastre-se com seu nome, e-mail e senha.
3. Volte ao **SQL Editor** do Supabase e rode (trocando pelo seu e-mail):
   ```sql
   update public.profiles set role = 'admin' where email = 'seu-email@uniasselvi.com.br';
   ```
4. Faça logout e login de novo — agora sua conta é administradora.

## Como funcionam as permissões
- **Colaborador comum**: no "Meu quadro" só vê e edita (arrasta, muda status, anota) os contatos atribuídos a ele. Na aba **"Todos os atendimentos"** vê uma tabela com os contatos de todo mundo, mas sem poder editar — só consultar.
- **Administrador (você)**: o "Quadro (todos)" já mostra os contatos de todos os colaboradores, com edição liberada, incluindo reatribuir o responsável e ler/adicionar anotações em qualquer contato.
- A importação de CSV: colaboradores comuns só importam para si mesmos; o administrador pode escolher para quem atribuir.
- Isso tudo é garantido no banco (Row Level Security), não só na tela — mesmo que alguém tente burlar a interface, o Supabase bloqueia a edição/exclusão de contatos que não são dele.

## Próximos passos possíveis
- Hospedar o `index.html` em um link fixo (Netlify/Vercel são gratuitos e simples).
- Trocar a senha do banco periodicamente e nunca compartilhar a "service role key" (só use a anon public key no front-end).
- Se quiser, dá pra adicionar recuperação de senha, edição de nome do colaborador, ou promover/rebaixar admins pela própria tela (hoje isso é feito por SQL, propositalmente, para manter o controle nas suas mãos).
