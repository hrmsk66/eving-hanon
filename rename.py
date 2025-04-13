import os
import re
import subprocess

def rename_and_convert_files(directory):
    """
    指定したディレクトリ内のファイル名を変更し、mp3ファイルをm4aファイルに変換する。
    変換後、元のmp3ファイルは削除される。
    """
    for filename in os.listdir(directory):
        if filename.endswith(".mp3"):
            # ファイル名を小文字に変換
            new_filename = filename.lower()
            
            # 末尾が slow のファイルは処理せず削除
            if "_slow" in new_filename or "_slow." in new_filename:
                os.remove(os.path.join(directory, filename))
                print(f"Deleted slow file: '{filename}'")
                continue
                
            # Dialog を含むファイルの処理
            dialog_match = re.match(r"\d+_dialog (\d+)\.(\d+).*\.mp3", new_filename)
            if dialog_match:
                unit_number = dialog_match.group(1)
                lesson_number = dialog_match.group(2)
                
                # 番号が1桁の場合、0を追加
                if len(unit_number) == 1:
                    unit_number = "0" + unit_number
                if len(lesson_number) == 1:
                    lesson_number = "0" + lesson_number
                    
                new_filename = f"dialog{unit_number}{lesson_number}.m4a"
                old_filepath = os.path.join(directory, filename)
                new_filepath = os.path.join(directory, new_filename)
                
                # mp3ファイルをm4aファイルに変換
                subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", old_filepath, new_filepath])
                # mp3ファイルを削除
                os.remove(old_filepath)
                print(f"Renamed and converted '{filename}' to '{new_filename}'")
                continue
                
            # Drill を含むファイルの処理
            drill_match = re.match(r"\d+_drill (\d+)\.(\d+).*\.mp3", new_filename)
            if drill_match:
                unit_number = drill_match.group(1)
                lesson_number = drill_match.group(2)
                
                # 番号が1桁の場合、0を追加
                if len(unit_number) == 1:
                    unit_number = "0" + unit_number
                if len(lesson_number) == 1:
                    lesson_number = "0" + lesson_number
                    
                new_filename = f"drill{unit_number}{lesson_number}.m4a"
                old_filepath = os.path.join(directory, filename)
                new_filepath = os.path.join(directory, new_filename)
                
                # mp3ファイルをm4aファイルに変換
                subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", old_filepath, new_filepath])
                # mp3ファイルを削除
                os.remove(old_filepath)
                print(f"Renamed and converted '{filename}' to '{new_filename}'")
                continue
            
            # Unit ファイルの処理
            unit_match = re.match(r"\d+_unit (\d+)\.(\d+)(?:_(\w+))?\.mp3", new_filename)
            if unit_match:
                unit_number = unit_match.group(1)
                lesson_number = unit_match.group(2)
                keyword = unit_match.group(3)
                
                # ユニット番号が1桁の場合、0を追加
                if len(unit_number) == 1:
                    unit_number = "0" + unit_number
                # レッスン番号が1桁の場合、0を追加
                if len(lesson_number) == 1:
                    lesson_number = "0" + lesson_number
                    
                # 末尾の natural は不要
                if keyword and keyword.lower() == "natural":
                    new_filename = f"lesson{unit_number}{lesson_number}.m4a"
                elif keyword:
                    new_filename = f"lesson{unit_number}{lesson_number}_{keyword}.m4a"
                else:
                    new_filename = f"lesson{unit_number}{lesson_number}.m4a"
                
                old_filepath = os.path.join(directory, filename)
                new_filepath = os.path.join(directory, new_filename)
                
                # mp3ファイルをm4aファイルに変換
                subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", old_filepath, new_filepath])
                # mp3ファイルを削除
                os.remove(old_filepath)
                print(f"Renamed and converted '{filename}' to '{new_filename}'")

# スクリプトを実行するディレクトリを指定
directory_path = "/Users/kake/Documents/Hanon/advanced"  # 実際のディレクトリパスに置き換えてください
rename_and_convert_files(directory_path)
