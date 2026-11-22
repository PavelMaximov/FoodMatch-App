-- Optional display text only; canonical recipe IDs and values are unchanged.
alter table public.dishes add column content_translations jsonb not null default '{}'::jsonb
  check (jsonb_typeof(content_translations) = 'object');
alter table public.shared_shopping_list_items add column name_de text
  check (name_de is null or length(name_de) between 1 and 500);
-- Catalog access remains server-only under existing RLS and grants.
revoke insert, update, delete on public.dishes from anon, authenticated;

-- Editing source copy invalidates its translation instead of displaying stale text.
create function public.invalidate_dish_content_translation() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_table_name='dishes' then
    if row(new.name,new.description,new.yields) is distinct from row(old.name,old.description,old.yields) then
      new.content_translations := '{}'::jsonb;
    end if;
    return new;
  end if;
  if tg_op <> 'INSERT' then
    update public.dishes set content_translations='{}'::jsonb where id=old.dish_id and content_translations<>'{}'::jsonb;
  end if;
  if tg_op <> 'DELETE' then
    update public.dishes set content_translations='{}'::jsonb where id=new.dish_id and content_translations<>'{}'::jsonb;
  end if;
  return null;
end;
$$;
revoke all on function public.invalidate_dish_content_translation() from public,anon,authenticated;
create trigger invalidate_dish_content_translation before update of name,description,yields on public.dishes
 for each row execute function public.invalidate_dish_content_translation();
create trigger invalidate_section_content_translation after insert or update or delete on public.dish_sections
 for each row execute function public.invalidate_dish_content_translation();
create trigger invalidate_component_content_translation after insert or update or delete on public.dish_components
 for each row execute function public.invalidate_dish_content_translation();
create trigger invalidate_instruction_content_translation after insert or update or delete on public.dish_instructions
 for each row execute function public.invalidate_dish_content_translation();
