# QA Checklist

## Before starting
- Run the app once in local-only mode without `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- If remote sync must be validated, apply `docs/sql/block_15_offline_sync_team.sql` in Supabase and run the app again with both dart defines.
- Validate at least one compact width and one wide width:
  - phone width around `390x844`
  - web width around `1440x900`

## Global shell and navigation
- Open the app and confirm the initial shell loads without crashes.
- Check bottom navigation on compact width.
- Check navigation rail on wide width.
- Confirm the offline banner appears only when remote config is absent or failed.
- Open `Negócio` from the shell banner action.

## Dashboard
- Confirm the dashboard opens with summary cards, `O que fazer hoje`, agenda, alerts, and finance summary.
- Tap each summary card and verify navigation reaches the expected module.
- Validate the dashboard empty and loading states still read naturally in pt-BR.

## Orders
- Create a new order with client, items, total, deposit, and notes.
- Save an incomplete draft and reopen it.
- Confirm a complete order and review the generated `Resumo`, `Produção`, `Materiais`, and `Financeiro`.
- Validate the order list filters and grouped reading on both compact and wide layouts.
- Open quote preview and share summary from order details.

## Clients and monthly plans
- Create a client with phone, notes, and one important date.
- Open the client detail page and confirm order history and mesversário area load correctly.
- Create a new mesversário linked to the client.
- Confirm recurrence, remaining balance, and future impact preview behave as expected.
- Generate a future draft order from the mesversário and confirm the occurrence history updates.

## Products, recipes, ingredients, packaging, suppliers
- Create one product with flavor or variation options.
- Create one recipe linked to ingredients and confirm cost summary renders.
- Create one ingredient with stock and preferred supplier.
- Create one packaging item and link it as compatible with a product.
- Create one supplier and register a price history entry.
- Review each list page on wide and compact widths for spacing, summary cards, filters, and empty states.

## Production and purchases
- Confirm a confirmed order generates production tasks and material needs.
- Move one production task to `Em produção` and then `Concluída`.
- Validate ingredient or packaging stock is reduced only once.
- Open `Compras` and confirm projected needs reflect active orders only.
- Register a purchase and confirm stock movement plus prepared expense draft behavior.
- Open the cost-benefit comparator and verify import from ingredient context still works.

## Finance
- Open `Visão geral`, `Recebimentos`, `Saídas`, and `Lançamentos`.
- Mark a receivable as received and confirm totals update.
- Mark a prepared expense as paid.
- Create a manual income or expense entry and confirm filters still behave correctly.

## Business settings, sync, and commercial layer
- Open `Negócio` and confirm the sync card shows team, pending changes, and helper text.
- In offline-only mode, confirm the app does not crash and the sync CTA stays disabled.
- With remote config present, press `Sincronizar agora` and check that success or failure feedback is visible.
- Open `Marca e orçamento`, save settings, and confirm values are reused in quote preview and share text.

## Responsive polish
- Check all major list pages for clipped buttons, stretched cards, or broken wraps on compact width.
- Check summary metric cards for consistent spacing and hierarchy across modules.
- Check empty, loading, and error states on wide width to ensure they do not stretch awkwardly.

## Regression notes to record
- Any screen with clipped actions or overlapping chips.
- Any copy that sounds technical, inconsistent, or not pt-BR natural.
- Any flow that requires too many taps for the main action.
- Any action that fails silently instead of explaining the next step.
