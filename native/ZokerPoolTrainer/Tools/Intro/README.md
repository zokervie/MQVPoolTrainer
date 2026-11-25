# Intro Zokervie — nguồn dựng (tài sản tự làm)

- `zokervie_intro_c.py`: kịch bản C "Cú đánh hai băng", 6 giây. Blender 4.5 LTS (bản cuối còn chạy Mac Intel), Cycles CPU.
  `Blender -b -P zokervie_intro_c.py -- --out DIR --w 960 --h 540 --samples 16 --fps 30 --video --wav /đường/dẫn/tuyệt/đối.wav --font Montserrat-SemiBold.ttf [--sub] [--frames a-b]`
  `--sub` thêm dòng BILLIARDS dưới chữ ZOKERVIE. Bản chính: `--w 1920 --h 1080 --samples 96 --fps 60`.
- `zokervie_intro_c_stills.py`: 3 ảnh tĩnh duyệt bố cục.
- Âm thanh: `Tools/AudioSources/intro_c_sfx_0590.py` (tổng hợp hoàn toàn, numpy + scipy), xuất WAV 48 kHz stereo 6 giây, −1 dBFS.
- Font: Montserrat SemiBold (OFL) — ghi công trong màn Pháp lý.
- Hình học: chữ Z là đường phản xạ gương của cú hai băng giữa hai băng dài; bàn xoay 22,5° trong khung hình.
- Bài học: đường dẫn WAV tương đối cho tiếng câm; TRACK_TO lật khi nhìn thẳng xuống (tự tính góc máy quay); bi "nhảy chỗ" qua vết cắt gây nhoè (dùng hai viên bi riêng).
