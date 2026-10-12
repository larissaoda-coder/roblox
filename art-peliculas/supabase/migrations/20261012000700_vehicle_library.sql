-- =====================================================================
-- Art Películas — biblioteca inicial de veículos populares no Brasil
-- =====================================================================
-- Os anos se referem a anos-modelo aproximados no mercado brasileiro e podem
-- ser ajustados pelo administrador. Nenhuma imagem ou modelo 3D é incluído:
-- as mídias devem ser cadastradas pelo painel, com origem/autorização informada.

alter table public.vehicles disable trigger vehicles_audit;

insert into public.vehicles (brand, model, generation, year_start, year_end, category, doors, notes) values
  ('Volkswagen', 'Gol', 'G5', 2009, 2012, 'hatch', 4, ''),
  ('Volkswagen', 'Gol', 'G6', 2013, 2016, 'hatch', 4, ''),
  ('Volkswagen', 'Gol', 'G7', 2017, 2023, 'hatch', 4, 'Inclui as reestilizações posteriores a 2018.'),
  ('Volkswagen', 'Fox', '1ª geração', 2004, 2021, 'hatch', 4, 'Geração única com reestilizações.'),
  ('Volkswagen', 'Polo', '6ª geração', 2018, null, 'hatch', 4, 'Inclui a versão Polo Track.'),
  ('Volkswagen', 'Virtus', '1ª geração', 2018, null, 'sedan', 4, ''),
  ('Volkswagen', 'Voyage', '2ª geração', 2009, 2023, 'sedan', 4, ''),
  ('Volkswagen', 'Saveiro', 'Atual (desde 2010)', 2010, null, 'picape', null, 'Cabine simples, estendida ou dupla: confira os vidros traseiros.'),
  ('Volkswagen', 'T-Cross', '1ª geração', 2020, null, 'suv', 4, ''),
  ('Volkswagen', 'Nivus', '1ª geração', 2021, null, 'suv', 4, ''),

  ('Fiat', 'Uno', 'Mille', 1990, 2013, 'hatch', null, 'Versões de 2 e 4 portas.'),
  ('Fiat', 'Uno', '2ª geração (Novo Uno)', 2011, 2021, 'hatch', 4, ''),
  ('Fiat', 'Palio', '2ª geração (Novo Palio)', 2012, 2017, 'hatch', 4, ''),
  ('Fiat', 'Mobi', '1ª geração', 2017, null, 'hatch', 4, ''),
  ('Fiat', 'Argo', '1ª geração', 2018, null, 'hatch', 4, ''),
  ('Fiat', 'Cronos', '1ª geração', 2018, null, 'sedan', 4, ''),
  ('Fiat', 'Strada', '1ª geração', 1998, 2020, 'picape', null, 'Cabine simples, estendida ou dupla: confira os vidros traseiros.'),
  ('Fiat', 'Strada', '2ª geração', 2021, null, 'picape', null, 'Cabine Plus ou dupla: confira os vidros traseiros.'),
  ('Fiat', 'Toro', '1ª geração', 2016, null, 'picape', 4, ''),
  ('Fiat', 'Pulse', '1ª geração', 2022, null, 'suv', 4, ''),
  ('Fiat', 'Fastback', '1ª geração', 2023, null, 'suv', 4, 'SUV com caimento cupê.'),

  ('Chevrolet', 'Celta', '1ª geração', 2001, 2015, 'hatch', null, 'Versões de 2 e 4 portas.'),
  ('Chevrolet', 'Onix', '1ª geração', 2013, 2019, 'hatch', 4, ''),
  ('Chevrolet', 'Onix', '2ª geração', 2020, null, 'hatch', 4, ''),
  ('Chevrolet', 'Onix Plus', '1ª geração', 2020, null, 'sedan', 4, ''),
  ('Chevrolet', 'Prisma', '2ª geração', 2013, 2019, 'sedan', 4, ''),
  ('Chevrolet', 'Tracker', '2ª geração', 2021, null, 'suv', 4, ''),
  ('Chevrolet', 'Spin', '1ª geração', 2013, null, 'minivan', 4, ''),
  ('Chevrolet', 'S10', '2ª geração', 2012, null, 'picape', 4, 'Cabine dupla.'),
  ('Chevrolet', 'Montana', '3ª geração', 2023, null, 'picape', 4, ''),

  ('Hyundai', 'HB20', '1ª geração', 2013, 2019, 'hatch', 4, ''),
  ('Hyundai', 'HB20', '2ª geração', 2020, null, 'hatch', 4, ''),
  ('Hyundai', 'HB20S', '2ª geração', 2020, null, 'sedan', 4, ''),
  ('Hyundai', 'Creta', '1ª geração', 2017, 2021, 'suv', 4, ''),
  ('Hyundai', 'Creta', '2ª geração', 2022, null, 'suv', 4, ''),

  ('Toyota', 'Corolla', '11ª geração', 2015, 2019, 'sedan', 4, ''),
  ('Toyota', 'Corolla', '12ª geração', 2020, null, 'sedan', 4, ''),
  ('Toyota', 'Corolla Cross', '1ª geração', 2022, null, 'suv', 4, ''),
  ('Toyota', 'Etios', '1ª geração', 2013, 2021, 'hatch', 4, ''),
  ('Toyota', 'Hilux', '8ª geração', 2016, null, 'picape', 4, 'Cabine dupla.'),

  ('Honda', 'Civic', '9ª geração', 2012, 2016, 'sedan', 4, ''),
  ('Honda', 'Civic', '10ª geração', 2017, 2021, 'sedan', 4, ''),
  ('Honda', 'Fit', '3ª geração', 2015, 2021, 'hatch', 4, ''),
  ('Honda', 'HR-V', '1ª geração', 2015, 2022, 'suv', 4, ''),
  ('Honda', 'HR-V', '2ª geração', 2023, null, 'suv', 4, ''),

  ('Renault', 'Sandero', '1ª geração', 2008, 2014, 'hatch', 4, ''),
  ('Renault', 'Sandero', '2ª geração', 2015, 2022, 'hatch', 4, ''),
  ('Renault', 'Logan', '2ª geração', 2014, 2022, 'sedan', 4, ''),
  ('Renault', 'Kwid', '1ª geração', 2018, null, 'hatch', 4, ''),
  ('Renault', 'Duster', '2ª geração', 2021, null, 'suv', 4, ''),
  ('Renault', 'Oroch', '1ª geração', 2016, null, 'picape', 4, ''),

  ('Jeep', 'Renegade', '1ª geração', 2015, null, 'suv', 4, ''),
  ('Jeep', 'Compass', '2ª geração', 2017, null, 'suv', 4, ''),
  ('Nissan', 'Kicks', '1ª geração', 2017, null, 'suv', 4, 'Também comercializado como Kicks Play.'),
  ('Ford', 'Ka', '3ª geração', 2015, 2021, 'hatch', 4, ''),
  ('Ford', 'EcoSport', '2ª geração', 2013, 2021, 'suv', 4, ''),
  ('Peugeot', '208', '2ª geração', 2021, null, 'hatch', 4, ''),
  ('BYD', 'Dolphin', '1ª geração', 2023, null, 'hatch', 4, 'Elétrico.'),
  ('BYD', 'Dolphin Mini', '1ª geração', 2024, null, 'hatch', 4, 'Elétrico.')
on conflict do nothing;

alter table public.vehicles enable trigger vehicles_audit;
