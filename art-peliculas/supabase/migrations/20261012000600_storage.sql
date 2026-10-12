-- =====================================================================
-- Art Películas — armazenamento de imagens, modelos 3D e logotipo
-- =====================================================================
-- Bucket privado "media":
--   vehicles/<veículo>/<arquivo>   imagens autorizadas dos veículos
--   models/<veículo>/<arquivo>     modelos 3D (.glb)
--   branding/<arquivo>             logotipo usado nos orçamentos impressos

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media',
  'media',
  false,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp', 'model/gltf-binary', 'application/octet-stream']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.can_write_media(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case split_part(object_name, '/', 1)
    when 'vehicles' then public.has_permission('veiculos.gerenciar')
    when 'models' then public.has_permission('veiculos.gerenciar')
    when 'branding' then public.has_permission('configuracoes.gerenciar')
    else false
  end;
$$;

grant execute on function public.can_write_media(text) to authenticated;

create policy "media: leitura por usuários ativos" on storage.objects
  for select to authenticated
  using (bucket_id = 'media' and (select public.is_active_user()));

create policy "media: envio conforme permissão" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media' and public.can_write_media(name));

create policy "media: atualização conforme permissão" on storage.objects
  for update to authenticated
  using (bucket_id = 'media' and public.can_write_media(name))
  with check (bucket_id = 'media' and public.can_write_media(name));

create policy "media: remoção conforme permissão" on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and public.can_write_media(name));
