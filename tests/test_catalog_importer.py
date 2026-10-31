import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT / 'tools/catalog'
spec = importlib.util.spec_from_file_location('import_games', ROOT / 'import_games.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ImporterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = json.loads((ROOT/'schema.json').read_text(encoding='utf-8'))
        cls.raw = json.loads((PROJECT/'tests/fixtures/catalog_rows.json').read_text(encoding='utf-8'))

    def changed(self, index=0, **values):
        raw = copy.deepcopy(self.raw)
        raw['游戏资料'][index][1].update(values)
        return raw

    def reject(self, raw, text):
        with self.assertRaisesRegex(mod.ImportFailure, text):
            mod.validate(raw, self.schema)

    def test_actual_header_row_and_hardware_aliases(self):
        raw = mod.read_xlsx(ROOT/'game_catalog.xlsx', self.schema)
        self.assertEqual(list(raw),['游戏资料'])
        self.assertGreater(raw['游戏资料'][0][0],1)
        self.assertIn('cpu',raw['游戏资料'][0][1])
        self.assertIn('gpu',raw['游戏资料'][0][1])
        self.assertNotIn('capsule',raw['游戏资料'][0][1])
        self.assertNotIn('游戏原型', raw['游戏资料'][0][1])

    def test_every_game_derives_its_five_asset_paths(self):
        data,warnings=mod.validate(self.raw,self.schema)
        self.assertEqual(len(data['游戏资料']),12)
        self.assertFalse(warnings)
        for game in data['游戏资料']:
            game_id=game['game_id']
            self.assertEqual(game['capsule'],f'res://assets/art/{game_id}/{game_id}.png')
            self.assertEqual(game['screenshots'],[f'res://assets/art/{game_id}/{game_id}{i:02d}.png' for i in range(1,5)])

    def test_only_fourteen_game_fields_are_emitted(self):
        data,_=mod.validate(self.raw,self.schema)
        files=mod.render_files(data,'data/games')
        self.assertEqual(len(files),14)
        self.assertTrue(all(path.endswith('.tres') or path == 'README.txt' for path in files))
        self.assertIn('res://scripts/game.gd', files['distant_signal.tres'].decode())
        text=files['distant_signal.tres'].decode()
        body=text.split('[resource]\n',1)[1]
        keys={line.split(' = ',1)[0] for line in body.splitlines() if ' = ' in line}
        self.assertEqual(keys,{'script','game_id','title','announce_ym','store_release_ym','delist_ym','base_price','developer','genres','cpu','gpu','series_id','description','capsule','screenshots'})

    def test_manifest_preserves_spreadsheet_row_order(self):
        data,_=mod.validate(self.raw,self.schema)
        data['游戏资料'].reverse()
        files=mod.render_files(data,'data/games')
        manifest=files['_catalog.tres'].decode()
        first=data['游戏资料'][0]['game_id']
        last=data['游戏资料'][-1]['game_id']
        self.assertLess(manifest.index('/'+first+'.tres'),manifest.index('/'+last+'.tres'))

    def test_check_detects_stale_generated_resource(self):
        data,_=mod.validate(self.raw,self.schema)
        files=mod.render_files(data,'data/games')
        with tempfile.TemporaryDirectory() as temp:
            project=Path(temp)
            target=mod.write_output(project,'data/games',files)
            mod.check_output(project,'data/games',files)
            (target/'distant_signal.tres').write_text('stale')
            with self.assertRaisesRegex(mod.ImportFailure,'与表格不一致'):
                mod.check_output(project,'data/games',files)

    def test_duplicate_game_id(self):
        self.reject(self.changed(index=1,game_id='distant_signal'),'重复game_id')

    def test_invalid_month(self):
        self.reject(self.changed(store_release_ym=200313),'YYYYMM')

    def test_excel_date_serial_rejected(self):
        self.reject(self.changed(store_release_ym=37865),'YYYYMM')

    def test_negative_price(self):
        self.reject(self.changed(base_price=-1),'负数')

    def test_fraction_price(self):
        self.reject(self.changed(base_price=12.5),'整数')

    def test_formula_rejected(self):
        self.reject(self.changed(base_price=('FORMULA',)),'不接受公式')

    def test_whitespace_title_rejected(self):
        self.reject(self.changed(title='   '),'空白文本')

    def test_announcement_order(self):
        self.reject(self.changed(announce_ym=200310),'预告月份')

    def test_delist_order(self):
        self.reject(self.changed(delist_ym=200309),'下架月份')

    def test_disabled_game_is_excluded(self):
        data,_=mod.validate(self.changed(enabled=0,title=''),self.schema)
        self.assertEqual(len(data['游戏资料']),11)

    def test_blank_optional_fields_and_free_game(self):
        data,_=mod.validate(self.changed(base_price=0,cpu='',gpu='',announce_ym='',delist_ym='',genres=''),self.schema)
        game=data['游戏资料'][0]
        self.assertEqual(game['base_price'],0)
        self.assertEqual(game['genres'],[])
        text=mod.resource_game(game)
        self.assertIn('capsule = ExtResource("2_capsule")',text)
        self.assertEqual(len(game['screenshots']),4)

    def test_multiple_genres_split(self):
        data,_=mod.validate(self.changed(genres='科幻;探索'),self.schema)
        self.assertEqual(data['游戏资料'][0]['genres'],['科幻','探索'])

    def test_slash_genres_trim_whitespace_and_empty_segments(self):
        data,_=mod.validate(self.changed(genres=' 射击 / 动作// 多人 / '),self.schema)
        self.assertEqual(data['游戏资料'][0]['genres'],['射击','动作','多人'])
        self.reject(self.changed(genres='射击/射击'),'重复项')

    def test_current_counter_squad_workbook_and_five_assets(self):
        raw=mod.read_xlsx(ROOT/'game_catalog.xlsx',self.schema)
        data,_=mod.validate(raw,self.schema,PROJECT)
        self.assertTrue(data['游戏资料'])
        game=next(g for g in data['游戏资料'] if g['game_id']=='CounterSquad')
        self.assertEqual(game['game_id'],'CounterSquad')
        self.assertEqual(game['capsule'],'res://assets/art/CounterSquad/CounterSquad.png')
        self.assertEqual(game['screenshots'],[f'res://assets/art/CounterSquad/CounterSquad{i:02d}.png' for i in range(1,5)])
        files=mod.render_files(data,'data/games')
        self.assertEqual(set(files),{g['game_id']+'.tres' for g in data['游戏资料']}|{'_catalog.tres','README.txt'})
        mod.check_output(PROJECT,'data/games',files)
        text=files['CounterSquad.tres'].decode()
        self.assertIn('game_id = &"CounterSquad"',text)
        self.assertIn('load_steps=7',text)
        self.assertIn('screenshots = Array[Texture2D]([ExtResource("shot_01"), ExtResource("shot_02"), ExtResource("shot_03"), ExtResource("shot_04")])',text)

    def test_case_only_duplicate_ids_rejected(self):
        self.reject(self.changed(index=1,game_id='Distant_Signal'),'重复game_id')

    def test_old_capsule_values_cannot_override_automatic_paths(self):
        for value in ('res://assets/art/stars.png','res://../secret.png','', 'res://other/CounterSquad'):
            raw=self.changed(game_id='CounterSquad',capsule=value)
            raw['游戏资料']=raw['游戏资料'][:1]
            data,_=mod.validate(raw,self.schema,PROJECT)
            self.assertEqual(data['游戏资料'][0]['capsule'],'res://assets/art/CounterSquad/CounterSquad.png')

    def test_game_id_case_is_preserved_in_all_paths(self):
        data,_=mod.validate(self.changed(game_id='MixedCaseGame'),self.schema)
        game=data['游戏资料'][0]
        self.assertEqual(game['capsule'],'res://assets/art/MixedCaseGame/MixedCaseGame.png')
        self.assertTrue(all('/MixedCaseGame/MixedCaseGame' in path for path in game['screenshots']))

    def test_missing_screenshot_stops_import_before_writing(self):
        raw=self.changed(game_id='CounterSquad')
        with tempfile.TemporaryDirectory() as temp:
            project=Path(temp)
            folder=project/'assets/art/CounterSquad'
            folder.mkdir(parents=True)
            for name in ['CounterSquad.png','CounterSquad01.png','CounterSquad02.png','CounterSquad04.png']:
                (folder/name).touch()
            with self.assertRaisesRegex(mod.ImportFailure,'CounterSquad03.png'):
                mod.validate(raw,self.schema,project)
            self.assertFalse((project/'data/games').exists())

    def test_skip_asset_check_still_resolves_folder(self):
        data,_=mod.validate(self.changed(game_id='CounterSquad'),self.schema,Path('/missing-project'),True)
        self.assertEqual(len(data['游戏资料'][0]['screenshots']),4)

    def test_blank_enabled_rows_remain_drafts(self):
        data,_=mod.validate(self.changed(enabled='',title='',game_id=''),self.schema)
        self.assertEqual(len(data['游戏资料']),11)


    def test_unrecognized_header_is_still_rejected(self):
        schema=copy.deepcopy(self.schema)
        schema['ignored_headers']=[]
        with self.assertRaisesRegex(mod.ImportFailure,'未知.*游戏原型'):
            mod.read_xlsx(ROOT/'game_catalog.xlsx',schema)

    def test_hardware_models_are_verbatim(self):
        data,_=mod.validate(self.changed(cpu='AMD Ryzen 5 5600X',gpu='GeForce RTX 3060 12GB'),self.schema)
        text=mod.resource_game(data['游戏资料'][0])
        self.assertIn('cpu = "AMD Ryzen 5 5600X"',text)
        self.assertIn('gpu = "GeForce RTX 3060 12GB"',text)

    def test_path_traversal_rejected(self):
        self.reject(self.changed(game_id='../secret'),'英文字母')

    def test_missing_capsule_rejected(self):
        with self.assertRaisesRegex(mod.ImportFailure,'封面文件不存在'):
            mod.validate(self.changed(game_id='MissingArtGame'),self.schema,PROJECT)

    def test_escaped_resource_strings(self):
        data,_=mod.validate(self.changed(title='名字"引号\\路径',description='第一行\n第二行'),self.schema)
        text=mod.resource_game(data['游戏资料'][0])
        self.assertIn('名字\\"引号\\\\路径',text)
        self.assertIn('第一行\\n第二行',text)

    def test_output_regeneration_and_removal(self):
        data,_=mod.validate(self.raw,self.schema)
        files=mod.render_files(data,'data/games')
        with tempfile.TemporaryDirectory() as temp:
            project=Path(temp)
            target=mod.write_output(project,'data/games',files)
            mod.write_output(project,'data/games',files)
            self.assertEqual((target/'_catalog.tres').read_bytes(),files['_catalog.tres'])
            self.assertEqual((target/'README.txt').read_text(encoding='utf-8'),mod.GENERATED_README)
            data['游戏资料']=[g for g in data['游戏资料'] if g['game_id']!='distant_signal']
            mod.write_output(project,'data/games',mod.render_files(data,'data/games'))
            self.assertFalse((target/'distant_signal.tres').exists())

    def test_importer_leaves_authoritative_script_and_uid_untouched(self):
        data,_=mod.validate(self.raw,self.schema)
        files=mod.render_files(data,'data/games')
        with tempfile.TemporaryDirectory() as temp:
            project=Path(temp)
            script=project/'scripts/game.gd'
            script.parent.mkdir()
            script.write_text('extends Resource\n')
            uid=project/'scripts/game.gd.uid'
            uid.write_text('uid://c123456789\n')
            mod.write_output(project,'data/games',files)
            mod.write_output(project,'data/games',files)
            self.assertEqual(script.read_text(),'extends Resource\n')
            self.assertEqual(uid.read_text(),'uid://c123456789\n')
            mod.check_output(project,'data/games',files)

    def test_manual_file_protected(self):
        with tempfile.TemporaryDirectory() as temp:
            project=Path(temp)
            target=mod.write_output(project,'data/games',{'a.txt':b'original'})
            (target/'a.txt').write_text('edited')
            with self.assertRaisesRegex(mod.ImportFailure,'手工新增或修改'):
                mod.write_output(project,'data/games',{'a.txt':b'replace'})
            self.assertEqual((target/'a.txt').read_text(),'edited')

    def test_unknown_directory_protected(self):
        with tempfile.TemporaryDirectory() as temp:
            project=Path(temp)
            (project/'output').mkdir()
            with self.assertRaisesRegex(mod.ImportFailure,'不是本工具生成'):
                mod.write_output(project,'output',{'a.txt':b'test'})


if __name__=='__main__':
    unittest.main(verbosity=2)
