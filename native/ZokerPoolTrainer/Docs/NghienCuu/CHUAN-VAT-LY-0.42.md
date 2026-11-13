# Neo vật lý ZokerPoolTrainer vào số liệu đã đo

Phần lớn hệ số hiện tại của ZokerPoolTrainer đã nằm trong dải đo hoặc dải đã công bố. Sai lệch thật nằm ở ba chỗ. Thứ nhất, ma sát bi–bi của app (a = 0.05, `ballFrictionMin` 0.05) giữ μ cao hơn đường fit Marlow/Alciatore, nên throw ở cú nhanh, góc cắt lớn bị đẩy lên khoảng 3 lần. Thứ hai, mô hình băng tự viết bỏ qua mũi băng ở độ cao h = 7R/5 và ma sát với mặt bàn trong lúc va chạm, nên không tạo được topspin do băng gây ra, vốn là cơ chế làm bank "đi ngắn". Thứ ba, spin decay đang lệch giữa core (7) và app (15), trong khi giá trị tham chiếu là khoảng 10.9 rad/s². Sliding μs 0.20, rolling μr 0.012 và restitution bi–bi 0.94 đều đứng vững: Mathavan đo μs 0.178–0.245 và μr 0.0127–0.0129 bằng camera tốc độ cao. Hệ số băng 0.82 cũng khớp gần đúng với hệ số hiệu dụng đo được là 0.818. Bộ phương trình nên dùng đã khá ổn định trong tài liệu. Bi trên vải dùng mô hình ba trạng thái gia tốc hằng (Marlow, pooltool). Bi–bi dùng mô hình throw TP A-14 có trần no-slip 1/7. Băng dùng Mathavan 2010. Cú cơ dùng TP A-30/A-31. Mỗi phần đều có các đồng nhất thức giải tích dùng làm unit test chính xác, cộng một số dải đo dùng làm test dung sai. Điểm yếu lớn nhất của cả lĩnh vực là phần nhảy bi (jump) và spin decay: chưa nguồn nào đo trực tiếp, nên mọi giá trị ở đây phải gắn nhãn "giả định" và hiệu chỉnh theo video.

Quy ước nhãn trong báo cáo (theo quy tắc dự án): **đã đo** là giá trị từ thí nghiệm có mô tả; **đã công bố** là giá trị tham chiếu hoặc mặc định của code mở, không kèm thí nghiệm; **giả định** là ước lượng cần hiệu chỉnh; **suy ra** là số tính từ phương trình đã dẫn. Giá trị "suy ra" dùng làm đáp án test, không phải bằng chứng thực nghiệm.

## Bi trên vải có ba trạng thái gia tốc hằng; chỉ spin decay cần sửa

Mô hình chuẩn có ba trạng thái. Pooltool dùng nó theo Marlow, và nó cũng là nền của cách mô phỏng theo sự kiện. Trong trạng thái **trượt**, vận tốc trượt tại điểm tiếp xúc u = v + R k̂×ω giảm dọc một hướng cố định: **u(t) = (u₀ − (7/2)μs g t)·û₀**. Lực ma sát vì thế có độ lớn μs·m·g và hướng −û₀ không đổi. Bi chuyển sang lăn sau **τs = 2u₀/(7μs g)**. Trong trạng thái **lăn**, vận tốc giảm đều μr·g và bi dừng sau τr = |v₀|/(μr g). Spin quanh trục đứng giảm tuyến tính **ω_z(t) = ω₀z − (5μsp g/2R)·t** cả khi lăn lẫn khi đứng quay tại chỗ. Khi lăn, ω_z tách khỏi chuyển động tịnh tiến, nên sidespin đơn thuần không làm bi đang lăn cong đường ([pooltool theory, Kiefl](https://ekiefl.github.io/2020/04/24/pooltool-theory/)). Mọi trạng thái đều có gia tốc hằng, nên thời điểm chuyển trạng thái giải được dạng đóng. Đây là cơ sở để dùng các đáp án giải tích làm test, kể cả khi engine bước thời gian 1/960 s.

Từ đó suy ra các hệ thức dùng trực tiếp làm test. Vận tốc lăn cuối là **v_roll = v₀ − (2/7)u₀**. Với cú đi thẳng có topspin hoặc backspin, công thức thành (5/7)v₀ + (2/7)Rω. Cú stun đi được quãng trượt **d_s = 12v₀²/(49μs g)**. Lấy v₀ = 2 m/s và μs = 0.2 thì τs ≈ 0.291 s, d_s ≈ 0.499 m, và bi lăn ra với 1.4286 m/s (suy ra). Swerve và massé cũng đến từ cùng phương trình: lực ma sát có hướng cố định nên **quỹ đạo khi trượt là parabol chính xác**. Hướng thẳng cuối cùng theo v₀ − (2/7)u₀ và **không phụ thuộc μs**; μs chỉ làm đường cong lớn hay nhỏ, tỉ lệ với u₀²/(μs g). Điều này giải thích nhận xét của Dr. Dave rằng vải trơn làm massé "văng xa hơn" ([Dr. Dave cloth effects](https://drdavepoolinfo.com/?p=2596)), và cũng là cơ sở lý thuyết của phương pháp ngắm BAR ([Dr. Dave swerve/massé aiming](https://drdavepoolinfo.com/?p=2318)). Massé vì thế không cần code riêng. Một integrator xử lý đúng ω tùy ý trong trạng thái trượt sẽ tự tạo ra nó.

Về hệ số, số liệu tốt nhất là của Mathavan, Jackson & Parkin (2009). Họ dùng camera trần nhà tới 1000 fps trên bàn snooker và đo **gia tốc lăn 0.124–0.126 m/s² (μr = 0.0127–0.0129)** và **gia tốc trượt 1.75–2.40 m/s² (μs = 0.178–0.245)** ([Mathavan et al. 2009, AJP](https://drdavepoolinfo.com//physics_articles/ajp_09_hsv_article.pdf)). Cùng bài dẫn lại số của Marlow cho pool: μr 0.011–0.024 và μs 0.2. Bảng tham chiếu của Dr. Dave cho **μs 0.15–0.4 (điển hình 0.2), μr 0.005–0.015 và spin decay 5–15 rad/s²** ([Dr. Dave physical properties](https://billiards.colostate.edu/faq/physics/physical-properties/)). Pooltool đặt mặc định u_s = 0.2, u_r = 0.01 và u_sp = (4/9)R ≈ 0.0127, nhưng tự ghi chú là "not well-researched" ([pooltool params](https://pooltool.readthedocs.io/en/latest/_modules/pooltool/objects/ball/params.html)). Giá trị u_sp này cho α = 5·0.0127·9.81/(2·0.028575) ≈ **10.9 rad/s²**, khớp với con số 11 rad/s² mà một trang cũ của Colorado State đưa ra ([PhysicsForums](https://www.physicsforums.com/threads/billiards-rotational-friction-side-spin.282458/post-2021111)). Như vậy μs 0.20 và μr 0.012 của app đều đứng vững. Riêng μr đo trên vải snooker có tuyết, thường chậm hơn vải worsted của pool, nên 0.012 hợp với vải pool "trung bình, đã dùng một thời gian". Đây là suy luận, chưa có số đo cho từng loại vải như Simonis 760/860. Spin decay 7 (core) và 15 (app) đều nằm trong dải 5–15, nhưng nằm ở hai đầu dải. Nếu quy ra mô hình torque của vết tiếp xúc hình tròn với áp suất đều, hai giá trị này ứng với bán kính vết khoảng 1.75 mm và 3.7 mm, còn 10.9 ứng với khoảng 2.7 mm (suy ra). **Chưa có nguồn nào đo spin decay trên vải pool bằng phương pháp được mô tả**, nên dù chọn giá trị nào cũng chỉ có nhãn "đã công bố".

Với cú nhảy, tài liệu chỉ có giá trị tham chiếu: **restitution bi–mặt bàn e ≈ 0.5** (Dr. Dave, và là mặc định e_t của pooltool). Không có số đo theo tốc độ, cũng không có hệ số ma sát tiếp tuyến khi bi chạm bàn. Mô hình hợp lý là bi bay như vật ném xiên, không tính lực cản không khí, giữ nguyên ω. Mỗi lần chạm bàn thì v_z' = −e·v_z, và xung tiếp tuyến bị chặn bởi μ(1+e)m|v_z|, với μ ≈ μs. Mô hình này là giả định.

## Ma sát bi–bi phải lấy theo tốc độ trượt tại điểm tiếp xúc, có trần 1/7

Mô hình throw của Alciatore (TP A-14) cho vận tốc tiếp tuyến của bi mục tiêu (OB) là **v_OBt = min[μ(v_rel)·v·cosφ, v_rel/7]**. Ở đây v_rel là tốc độ trượt tại điểm tiếp xúc, gồm thành phần ngang (v·sinφ − Rω_z) và thành phần đứng (Rω_x·cosφ), không gồm thành phần pháp tuyến. Góc throw là θ = atan(v_OBt/(v·cosφ)), với giả thiết e = 1. Ma sát là đường fit của Alciatore lên dữ liệu Marlow (1995): **μ(v) = 0.00995 + 0.108·e^(−1.088·v)** ([TP A-14](https://drdavepoolinfo.com/technical_proofs/new/TP_A-14.pdf); dữ liệu gốc là Marlow Table 10, p. 245, theo [TP A-28](https://drdavepoolinfo.com/technical_proofs/new/TP_A-28.pdf)). Pooltool cài đúng đường fit này trong `AlciatoreBallBallFriction` và tính nó **theo tốc độ bề mặt tương đối tại điểm tiếp xúc, không theo tốc độ bi cái** ([pooltool friction.py](https://pooltool.readthedocs.io/en/v0.5.0/_modules/pooltool/physics/resolve/ball_ball/friction.html)). Số hạng v_rel/7 là điều kiện trượt kết thúc ngay trong lúc va chạm, tức hiện tượng "gearing". Nếu bỏ trần này, engine sẽ dự đoán throw quá lớn ở góc cắt nhỏ. Mô hình đóng tương đương, tổng quát cho trường hợp cả hai bi cùng chuyển động và có đủ các thành phần spin, là `FrictionalInelastic` của pooltool. Khi xung ma sát đủ làm đảo chiều trượt, mô hình này chuyển sang nghiệm no-slip Δv = −(1/7)[(v₁t − v₂t) + R(ω₁+ω₂)×n̂] ([pooltool frictional_inelastic](https://pooltool.readthedocs.io/en/v0.4.4/_modules/pooltool/physics/resolve/ball_ball/frictional_inelastic.html)). Đây là lựa chọn chính hợp lý cho core C++. Mô hình số của Mathavan 2014 có thêm ma sát với mặt bàn trong lúc va chạm và báo cáo độ chính xác hướng đi "tăng gấp đôi" so với thực nghiệm ([Springer](https://link.springer.com/article/10.1007/s12283-014-0158-y)). Tuy nhiên tham số của bài này nằm sau paywall, nên chỉ nên dùng làm phép đối chiếu.

Từ đây lộ ra sai lệch của app. Với a = 0.05 (cùng `ballFrictionMin` = 0.05), μ không bao giờ xuống dưới 0.05 và đạt 0.158 khi v → 0. Đường fit thì cho μ(2) = 0.022 và μ(5) = 0.010. Ở cú stun chậm, sai lệch này không thấy được vì cả hai đều chạm trần 1/7. Ví dụ ở 0.447 m/s và φ = 30°, cả hai cho 4.72°. Nhưng ở cú stun 3.129 m/s, φ = 45°, đường fit cho μ ≈ 0.020 và **throw ≈ 1.13°**, còn công thức của app cho μ ≈ 0.060 và **throw ≈ 3.4°**, tức khoảng 3 lần (suy ra từ phương trình TP A-14). Có thể giải thích a = 0.05 là cố ý chọn μ hằng nằm trong dải 0.03–0.08 mà Dr. Dave đưa ra ([Dr. Dave physical properties](https://drdavepoolinfo.com/faq/physics/physical-properties/)). Nhưng giá trị ở tốc độ thấp (0.158) đã vượt hẳn dải đó, nên cách giải thích này không khớp. Hiện tượng bi bẩn hoặc "cling" nên mô hình bằng một hệ số nhân μm. TP A-14 dùng 1.0 cho bi bình thường, 1.5 cho bi bẩn, 2.5 cho cling và tối đa khoảng 3. Với cling, đỉnh throw dịch từ khoảng 30° sang 50–60° ([TP A-14](https://drdavepoolinfo.com/technical_proofs/new/TP_A-14.pdf)). Không nên nâng sàn a lên cho mọi cú.

Kết quả đã công bố dùng để đối chiếu như sau. Throw lớn nhất khoảng 5–6°, rơi vào cú stun chậm gần nửa bi. BD tháng 9/2006 ghi 5.8° ở góc cắt khoảng 35°. Ở góc cắt 10°, throw khoảng 1.5° với mọi tốc độ, và dữ liệu đo của Jewett năm 1995 "khớp rất sát" ([BD Sept 2006](https://drdavepoolinfo.com/bd_articles/2006/sept06.pdf); [Dr. Dave Maximum Throw](https://drdavepoolinfo.com/faq/throw/maximum/)). Restitution bi–bi được trích nhất quán là **0.92–0.98**; không nguồn nào công bố đường cong e theo tốc độ. Giá trị e ảnh hưởng tới đường đi của bi cái nhiều hơn tới throw. Kim (2024) cho thấy ở φ = 30°, độ lệch của bi cái khỏi đường 90° là khoảng 4.0° khi e = 0.92 và khoảng 1.0° khi e = 0.98 ([Kim 2024, arXiv](https://arxiv.org/pdf/2402.13258v1)). Vì vậy 0.94 của app chấp nhận được, nhưng 0.95 (giữa dải) dễ bảo vệ hơn. Về truyền spin, TP A-27 cho Δω_OB = (5/2)(v/R)·tanθ_throw, bi cái mất lượng spin bằng như vậy, và tỉ lệ truyền tối đa là **5/14 ≈ 35.7%**, không phụ thuộc e ([TP A-27](https://drdavepoolinfo.com/technical_proofs/new/TP_A-27.pdf)).

## Hệ số băng 0.82 đúng về độ lớn, nhưng thiếu cơ chế quan trọng

Mathavan et al. (2010) mô hình băng là cứng, có hai điểm tiếp xúc: mũi băng I ở độ cao **h = 7R/5** (sinθ = 2/5) và điểm chạm bàn C. Cả hai có ma sát Coulomb. Mô hình tích phân theo xung pháp tuyến, gồm pha nén và pha hồi phục, và dừng khi W_rest = e²·W_comp. Các tham số **e = 0.98, μ_w = 0.14 (bi–băng) và μ_s = 0.21 (bi–bàn)** được fit vào số đo tốc độ bật lại. Kết quả khớp thực nghiệm khi tốc độ pháp tuyến dưới **2.5 m/s**; trên ngưỡng đó, tốc độ đo được thấp hơn, và tác giả quy cho biến dạng băng ([Loughborough repository](https://dspace.lboro.ac.uk/2134/15087); [Mathavan thesis](https://repository.lboro.ac.uk/articles/Trajectory_solutions_for_a_game-playing_robot_using_nonprehensile_manipulation_methods_and_machine_vision/9531635/files/17160473.pdf)). Pooltool có bản cài đặt đầy đủ, gồm các công thức trượt tại I và C cùng các bước ΔP ([pooltool mathavan_2010/model.py](https://github.com/ekiefl/pooltool/blob/main/pooltool/physics/resolve/ball_cushion/mathavan_2010/model.py)). Han 2005 là mô hình xung một điểm tiếp xúc, có dạng đóng, rẻ hơn. Nhưng nó bỏ ma sát với mặt bàn và giả định hướng trượt không đổi. Chính tác giả pooltool đánh giá Han "kém thực tế hơn Mathavan" ([pooltool theory](https://ekiefl.github.io/2020/04/24/pooltool-theory/); [han_2005/model.py](https://raw.githubusercontent.com/ekiefl/pooltool/main/pooltool/physics/resolve/ball_cushion/han_2005/model.py)). Chưa có nghiên cứu nào so sánh trực tiếp hai mô hình với góc bank đo được.

Cần tránh một bẫy khi chuyển mô hình. Con số **0.818** mà Mathavan (2009) đo trên 31 cú ở 0.28–3.5 m/s ([AJP 2009](https://drdavepoolinfo.com//physics_articles/ajp_09_hsv_article.pdf)) là tỉ số hiệu dụng của cả cú bật. Còn e = 0.98 là restitution ở cấp tiếp xúc; ma sát ở mũi băng và ở mặt bàn mới kéo tỉ số tổng xuống. Bản cài đặt lại mô hình Mathavan trong ghi chú nghiên cứu (giả định, chưa đối chiếu với hình trong bài báo; script ở `/tmp/claude-0/-home-claude/f7fb1d81-b8eb-5767-92bf-dd442d99400d/scratchpad/cush.py`) cho tỉ số pháp tuyến 0.91 với bi lăn vào vuông góc và 0.84 với bi stun. Vì vậy, nếu thay mô hình băng đơn giản bằng Mathavan, **e phải là 0.98, không phải 0.82**; dùng 0.82 sẽ tính tổn hao hai lần. Grip 0.16–0.20 của app nằm giữa μ_w = 0.14 (fit đo) và f_c = 0.2 (mặc định pooltool, đã công bố).

Mô hình đơn giản thiếu hai cơ chế mà người chơi thấy rõ. Cơ chế thứ nhất: mũi băng nằm trên xích đạo của bi, nên băng truyền topspin cho bi. Bi stun đánh dốc vào băng bật ra ở trạng thái lăn, còn bi đang lăn bật ra gần như stun ([Dr. Dave bank/kick effects](https://drdavepoolinfo.com/faq/bank-kick/effects/)). Topspin này sau đó gây massé sau băng, và đó là cơ chế khiến bank "cong ngắn" ([AzBilliards "Hard Banks Curve Short"](https://forums.azbilliards.com/goto/post?id=2730042)). Cơ chế thứ hai là phụ thuộc tốc độ. Mọi mô hình cứng với e và μ hằng đều bất biến theo tốc độ: bản cài đặt lại cho đúng tỉ số 0.848 và góc 52.7° tại V₀ = 0.5, 1, 2 và 3 m/s, với bi lăn vào ở 45°. Hiện tượng "bank mạnh đi ngắn" vì thế cần thêm hàm e_eff(v_n) giảm dần khi v_n vượt khoảng 2.5 m/s. Hình dạng hàm này **chưa có nguồn công bố** và phải hiệu chỉnh. Về chi phí tính toán: va chạm băng được giải như một sự kiện tức thời, độc lập với bước 1/960 s. Pooltool dùng 1000–5000 bước ΔP cho mỗi va chạm. Ước tính trong C++ là 50 µs tới 0.5 ms mỗi va chạm, đủ cho lúc chơi thật. Vì mô hình cứng bất biến theo tốc độ, có thể lập sẵn bảng tra 3 chiều (góc tới, topspin/V, sidespin/V) cho chế độ phân tích; đây là suy luận.

## Cú cơ có dạng đóng; squirt do end mass quyết định

Mô hình xung điểm tức thời dọc trục cơ (TP A-30, được pooltool cài thành `InstantaneousPoint3D`) cho tốc độ bi **v = (1+e)·V₀ / (1 + m/M + (5/2)(d/R)²)** và spin **ω = (5/2)·v·d/R²**. Tỉ số **ωR/v = 2.5·d/R** không phụ thuộc tốc độ và khối lượng. Pooltool cố định e = 1 (thừa số 2V₀). Khi cơ nâng góc θ, bi nhận thêm thành phần hướng xuống v·sinθ đâm vào mặt bàn ([pooltool source](https://raw.githubusercontent.com/ekiefl/pooltool/main/pooltool/physics/resolve/stick_ball/instantaneous_point/__init__.py)). Engine native muốn có jump và massé phải giữ thành phần này và giải va chạm bi–bàn, không được bỏ đi như bản 2D. Restitution đầu cơ–bi đo được là **0.71–0.75 với đầu da cứng vừa và 0.81–0.87 với đầu phenolic**. Đầu phenolic cho thêm khoảng 17% năng lượng phá ([Dr. Dave tip efficiency](https://drdavepoolinfo.com/faq/cue-tip/efficiency/)). Vì vậy cần thay hằng số 2 bằng (1+e) và lấy e theo loại đầu cơ.

Squirt theo TP A-31 (cài trong pooltool `get_squirt_angle`) là **α = atan[2.5·x·√(1−x²) / (1 + m_b/m_e + 2.5(1−x²))]**, với x là độ lệch ngang chia R và m_e là end mass hiệu dụng của phần ngọn cơ. Góc này không phụ thuộc tốc độ, và chỉ xoay vector vận tốc chứ không xoay spin ([pooltool squirt.py](https://raw.githubusercontent.com/ekiefl/pooltool/main/pooltool/physics/resolve/stick_ball/squirt.py)). Chỉ phần đầu cơ ảnh hưởng tới squirt, vì thời gian tiếp xúc dưới 1 ms và sóng uốn chỉ lan được khoảng 5–10 inch lên thân cơ ([Dr. Dave squirt cause](https://drdavepoolinfo.com/?p=2492)). Số đo cho squirt **0.5–2.3° (Shepard) và 1.3–2.3° (robot Platinum, khoảng 15 mph)** ([Dr. Dave published squirt data](https://drdavepoolinfo.com/?p=2503)). Cross ghi khoảng 1.8° ở b/r = 0.4 ([Cross](https://www.physics.usyd.edu.au/~cross/Billiards.htm)). Để rơi vào dải đo này, preset end mass cần vào khoảng 5–6 g cho shaft LD, 8–10 g cho shaft thường và 11–17 g cho cơ phá (giả định, hiệu chỉnh ngược từ dải squirt). Swerve không nên cộng vào lúc đánh; nó phải tự sinh ra từ integrator trong trạng thái trượt. Giới hạn miscue khoảng 0.5R chỉ là suy luận từ μ_tip ≈ 0.6–0.7 (tan(asin(d/R)) ≤ μ), chưa xác nhận được từ nguồn gốc.

Phần nhảy bi là lỗ hổng lớn nhất. Mô hình cứng ngây thơ (M = 0.567 kg, θ = 45°, V₀ = 4 m/s, e_bàn = 0.5) cho bi bay cao khoảng 0.24 m. Trong thực tế bi chỉ nảy vài cm. Vậy **e_bàn và khối lượng hiệu dụng của cơ nhảy phải hiệu chỉnh theo video** (ví dụ HSV B.44 cho thấy vải bị nén), không thể lấy từ tài liệu ([Dr. Dave jump technique](https://drdavepoolinfo.com/?p=2309)). Tốc độ phá của tay cơ chuyên nghiệp là **25–30 mph (11.2–13.4 m/s)** ([Dr. Dave break speed](https://drdavepoolinfo.com/?p=1895)). Đây là mốc trên cho thanh lực.

## Bộ test tham chiếu cho core C++

Các test được chia theo độ tin cậy. Nhóm **chính xác** là đồng nhất thức giải tích; dùng dung sai số học khoảng 1e-4 và cho fail cứng. Nhóm **suy ra** là số tính từ phương trình đã dẫn; chúng khóa hành vi mô hình (regression) và nên được đối chiếu lại với PDF gốc trước khi cố định. Nhóm **dải đo** là dải thực nghiệm, dùng làm test hợp lý. Theo quy tắc dự án, mỗi nhóm nên là một file `Tests/*.cpp`, đăng ký trong cả `CMakeLists.txt` (ZOKER_TEST_SUITES) và `Run-All-Checks.command`. Hằng số chung: R = 0.028575 m, m = 0.170097 kg, g = 9.81.

**Bi–vải** (nguồn phương trình: [pooltool theory](https://ekiefl.github.io/2020/04/24/pooltool-theory/))

| ID | Đầu vào | Kỳ vọng | Loại |
|---|---|---|---|
| C1 | Stun, v₀ = 2 m/s, μs = 0.2 | τs = 0.2912 s; d_s = 0.4993 m; v_roll = 1.4286 m/s | chính xác |
| C2 | Lăn 2 m/s, μr = 0.012 | dừng sau 16.99 m, τr = 16.99 s | chính xác |
| C3 | Draw, v₀ = 2, Rω = −2 m/s (u₀ = 4) | τs = 0.5824 s; v_roll = +0.857 m/s | chính xác |
| C4 | Lăn tự nhiên Rω = v₀ | u₀ = 0, không có pha trượt | chính xác |
| C5 | Quay tại chỗ ω₀z = 30 rad/s, α = 10.9 | dừng sau 2.75 s; bi lăn chỉ có sidespin vẫn đi thẳng | chính xác |
| C6 | Massé, cùng v₀/ω₀, μs 0.2 → 0.15 | hướng cuối giống nhau (v₀ − 2u₀/7); biên độ cong ×1.333 | chính xác |
| C7 | Rơi xuống bàn, e = 0.5 | độ cao lần nảy sau = 0.25 × lần trước | chính xác (e là giả định) |
| C8 | Gia tốc trượt / lăn đo được | 1.75–2.40 / 0.124–0.126 m/s² ([Mathavan 2009](https://drdavepoolinfo.com//physics_articles/ajp_09_hsv_article.pdf)) | dải đo |

**Bi–bi** (phương trình TP A-14, μ theo fit Marlow, e = 1 cho phép tính throw; [TP A-14](https://drdavepoolinfo.com/technical_proofs/new/TP_A-14.pdf), [TP A-4](https://drdavepoolinfo.com/technical_proofs/new/TP_A-4.pdf), [TP A-27](https://drdavepoolinfo.com/technical_proofs/new/TP_A-27.pdf))

| ID | Đầu vào | Kỳ vọng | Loại |
|---|---|---|---|
| B1 | μ = 0, e = 1, stun, mọi φ | hai bi tách đúng 90°; OB đi theo đường nối tâm | chính xác |
| B2 | μ = 0, e = 0.95, stun, φ = 30° | bi cái lệch atan(((1−e)/2)·cotφ) = 2.48°, tức tách 87.5° | chính xác |
| B3 | Quy tắc 30°: bi lăn, μ = 0, e = 1, φ = 30° | bi cái lệch 33.67° sau khi lăn lại | chính xác |
| B4 | Gearing: φ = 30°, outside ω_z = 0.5v/R, stun | throw = 0, OB không nhận spin | chính xác |
| B5 | Stun φ = 10°, v trong khoảng 0.4–3 m/s | throw = atan(tan10°/7) = 1.44° (đã công bố ≈1.5°) | suy ra / đã công bố |
| B6 | Stun 0.447 m/s | 4.72° ở 30°; đỉnh 5.30° ở 33° (dải công bố 5–6°) | suy ra |
| B7 | Stun φ = 45° ở 0.447 / 1.341 / 3.129 m/s | 4.95° / 2.77° / 1.13° | suy ra |
| B8 | φ = 30°, 1.341 m/s: lăn so với stun | 1.00° so với 3.55° | suy ra |
| B9 | SIT thẳng, inside 50% (ω_z = 0.625v/R) | 5.10° / 3.05° / 1.31° (chậm / vừa / nhanh) | suy ra |
| B10 | Truyền spin | Δω_OB = 2.5(v/R)·tanθ; ≤ 5/14 spin của bi cái; bi cái mất lượng bằng như vậy | chính xác |
| B11 | Bảo toàn | động lượng tuyến tính trong mặt phẳng (khi tắt ma sát bàn); mômen động lượng quanh điểm tiếp xúc | chính xác |
| B12 | Cling μm = 2.5, stun chậm | đỉnh throw dịch về 50–60° | đã công bố (định tính) |

**Bi–băng** (Mathavan 2010, e = 0.98, μ_w = 0.14, μ_s = 0.21, h = 7R/5)

| ID | Đầu vào | Kỳ vọng | Loại |
|---|---|---|---|
| K1 | Mọi V₀ dưới 2.5 m/s, góc và spin/V cố định | tỉ số tốc độ và góc ra không đổi (mô hình cứng) | chính xác |
| K2 | Lăn vào ở 45° so với băng, V₀ = 1 | ra 52.7° so với băng, 0.85V₀ | suy ra (giả định, chưa đối chiếu hình gốc) |
| K3 | Stun 45° / lăn 90° / stun 90° | 56.2° và 0.76V₀ / 0.91V₀ / 0.84V₀ | suy ra (giả định) |
| K4 | Lăn 45° kèm sidespin chạy / ngược (ω_z = ±V₀/R) | 43.2° và 0.94V₀ / 54.3° và 0.84V₀ (cần kiểm dấu) | suy ra (giả định) |
| K5 | Stun đánh dốc vào băng | bi ra có topspin (ω theo chiều lăn lên > 0) | đã công bố (định tính) ([Dr. Dave](https://drdavepoolinfo.com/faq/bank-kick/effects/)) |
| K6 | V₀ = 1 m/s, spin ω_S0 = −V₀/R, θ > 70° | bi bật về phía nó đến | đã công bố ([Mathavan thesis](https://repository.lboro.ac.uk/articles/Trajectory_solutions_for_a_game-playing_robot_using_nonprehensile_manipulation_methods_and_machine_vision/9531635/files/17160473.pdf)); cần đối chiếu định nghĩa trục ω_S |
| K7 | Kick thẳng vào băng với 1/3, 2/3, 3/3 sidespin tối đa | lệch khoảng 1, 2, 3 diamond | dải công bố (rule of thumb) |
| K8 | Cặp bank 20-10 / 40-20 / 60-30, độ mạnh vừa | pushback 4.5–12° | dải đo (một người chơi, bàn Gold Crown) ([AzB](https://forums.azbilliards.com/goto/post?id=2730042)) |
| K9 | Tốc độ pháp tuyến 2.5 m/s trở lên | tỉ số bật < giá trị của mô hình cứng (e_eff giảm) | đã đo (định tính) |

**Cơ–bi** (TP A-30/A-31 theo pooltool, M = 0.567 kg, V₀ = 2 m/s, θ = 0)

| ID | Đầu vào | Kỳ vọng | Loại |
|---|---|---|---|
| Q1 | Đánh tâm, e = 1 | v = 3.0769 m/s, ω = 0 | chính xác |
| Q2 | Top b = +0.5, e = 1 | v = 2.0779; ωR = 2.5974; ωR/v = 1.25 | chính xác |
| Q3 | Side a = +0.5, e = 1 | như Q2 cho \|ω_z\|R; squirt (m_b/m_e = 30) = 1.886° | chính xác |
| Q4 | Đánh tâm, e = 0.73 / 0.84 | v = 2.6615 / 2.8308 m/s | chính xác |
| Q5 | Bất biến | ωR/v = 2.5d/R với mọi V₀, M, e; squirt không đổi theo V₀; α(−x) = −α(x) | chính xác |
| Q6 | Bảng squirt | m_r 30, x 0.25 → 1.040°; m_r 20, x 0.5 → 2.709°; m_r 10, x 0.6 → 5.440° | chính xác |
| Q7 | Năng lượng | động năng bi + cơ sau va chạm ≤ động năng cơ trước (bằng nhau khi e = 1) | chính xác |
| Q8 | θ = 45°, V₀ = 4, e = 1 | v = 6.154; v_h = v_z(xuống) = 4.351 m/s; bi phải rời mặt vải sau khi nảy | chính xác (độ lớn cú nảy chưa hiệu chỉnh) |
| Q9 | Preset LD / thường ở x 0.25–0.5 | squirt nằm trong 0.5–2.3° | dải đo |

## Bảng tham số khuyến nghị

| Tham số | App hiện tại | Khuyến nghị | Dải cho slider / điều kiện | Nhãn nguồn |
|---|---|---|---|---|
| μs bi–vải (trượt) | 0.20 | **0.20** | 0.15 (vải mới, khô) – 0.30 (cũ, ẩm) | đã đo 0.178–0.245 ([Mathavan 2009](https://drdavepoolinfo.com//physics_articles/ajp_09_hsv_article.pdf)); đã công bố 0.15–0.4 |
| μr lăn | 0.012 | **0.012** | 0.006–0.020 | đã đo 0.0127–0.0129 (snooker); đã công bố 0.005–0.015 ([Dr. Dave](https://billiards.colostate.edu/faq/physics/physical-properties/)) |
| Spin decay quanh trục đứng | 7 (core) / 15 (app) | **10.9 rad/s²** (μsp ≈ 0.0127), một giá trị chung | 5–15 | đã công bố ([pooltool](https://pooltool.readthedocs.io/en/latest/_modules/pooltool/objects/ball/params.html), CSU 11); chưa có số đo |
| e bi–bi | 0.94 | **0.95** | 0.92–0.98 | đã công bố |
| μ bi–bi: a, b, c | a .00995 (core) / .05 (app); b .108; c 1.088 | **a 0.00995, b 0.108, c 1.088**, tính theo \|v_rel\| tại điểm tiếp xúc, có trần 1/7 | — | đã đo (fit dữ liệu Marlow 1995) ([TP A-14](https://drdavepoolinfo.com/technical_proofs/new/TP_A-14.pdf)) |
| `ballFrictionMin` | 0.05 | **bỏ** (hoặc ≤ 0.01) | — | suy ra (fit cho μ(5) = 0.010) |
| Hệ số cling μm | — | **1.0** | 1.0 / 1.5 bẩn / 2.5 cling / tối đa 3 | đã công bố (TP A-14) |
| e bi–băng | 0.82 (hiệu dụng) | **0.98 ở cấp tiếp xúc** nếu dùng Mathavan; **0.82** nếu giữ mô hình đơn giản | e_eff giảm khi v_n trên 2.5 m/s | đã đo (fit 0.98 trong [Mathavan 2010](https://dspace.lboro.ac.uk/2134/15087); hiệu dụng 0.818 trong Mathavan 2009) |
| μ bi–mũi băng (grip) | 0.16–0.20 | **0.14** | 0.14–0.20 | đã đo (fit, Mathavan 2010); 0.2 là mặc định pooltool (đã công bố) |
| μ bi–bàn khi va băng | — | **0.21** | = μs | đã đo (Mathavan thesis) |
| Độ cao mũi băng h | — | **7R/5 = 40.0 mm** | — | đã công bố (WPA, Mathavan) |
| e bi–mặt bàn (jump) | — | **0.5** | 0.3–0.6, hiệu chỉnh theo video | đã công bố, chưa đo; giả định về dải |
| e đầu cơ | (2V₀ ⇒ 1) | **0.73 da / 0.84 phenolic** | 0.71–0.75 / 0.81–0.87 | đã đo ([Dr. Dave](https://drdavepoolinfo.com/faq/cue-tip/efficiency/)) |
| Khối lượng cơ M | — | **0.567 kg** | 0.51–0.60 (18–21 oz) | đã công bố (mặc định pooltool) |
| End mass m_e | — | **LD 5.5 g / thường 9 g / phá 14 g** | 5–17 g | giả định (hiệu chỉnh để squirt rơi vào 0.5–2.3° đã đo) |
| Giới hạn miscue | — | **d ≤ 0.5R** | 0.45–0.57R | giả định (suy ra từ μ_tip 0.6–0.7) |
| Bi: m, R | — | 0.170 kg, 28.575 mm | — | đã công bố (6 oz, 2.25 in) |
| Tốc độ bi cái khi phá (mốc trên) | — | 11.2–13.4 m/s | — | đã đo (pro, [Dr. Dave](https://drdavepoolinfo.com/?p=1895)) |

## Thứ tự ưu tiên thay đổi mô hình

| Ưu tiên | Thay đổi | Lý do | Test chặn |
|---|---|---|---|
| 1 | Thống nhất spin decay về một tham số 10.9 rad/s² dùng chung cho core và app | Hai giá trị 7 và 15 cho thời gian sidespin tồn tại chênh nhau hơn 2 lần; thay đổi này rẻ nhất | C5 |
| 2 | Ma sát bi–bi: a = 0.00995, bỏ `ballFrictionMin`, tính μ theo \|v_rel\| tại điểm tiếp xúc, thêm trần no-slip 1/7 (dạng `FrictionalInelastic`), thêm μm cho cling | Throw ở cú nhanh, góc cắt lớn đang bị thổi lên khoảng 3 lần; ảnh hưởng trực tiếp tới việc luyện ngắm | B4–B10 |
| 3 | Thay mô hình băng đơn giản bằng Mathavan 2010 (h = 7R/5, e = 0.98, μ_w = 0.14, μ_s = 0.21), giới hạn số bước ΔP; giữ Han 2005 làm fallback | Tạo được topspin do băng và đường "cong ngắn"; mô hình băng có fit đo duy nhất | K1–K6 |
| 4 | Thêm e_eff(v_n) giảm dần trên 2.5 m/s, hiệu chỉnh để pushback rơi vào 4.5–12° | Mô hình cứng bất biến theo tốc độ, không tạo được "bank mạnh đi ngắn" | K8, K9 |
| 5 | Cú cơ: dùng (1+e) theo loại đầu cơ, squirt TP A-31 theo end mass, kiểm giới hạn miscue | Cơ sở để có preset shaft LD / thường; squirt rơi vào dải đo | Q1–Q9 |
| 6 | Kiểm tra integrator trượt với ω 3D tùy ý (để swerve/massé tự sinh ra); không cộng swerve ad hoc | Đảm bảo hướng cuối không phụ thuộc μs | C1, C3, C6 |
| 7 | Jump: giữ v_z khi cơ nâng góc, va chạm bi–bàn với e 0.5 và xung Coulomb, hiệu chỉnh e_bàn và khối lượng cơ nhảy theo video | Mô hình ngây thơ dự đoán độ cao gấp khoảng 5 lần thực tế; ghi rõ "chưa xác minh" | C7, Q8 |
| 8 | Preset điều kiện vải (μs, μr, spin decay) và độ sạch của bi (μm) | Trải nghiệm luyện tập trên nhiều loại bàn; các điểm giữa dải chưa có số đo | C8 |

## Kết luận

Phần chưa đúng của ZokerPoolTrainer không nằm ở các hệ số đơn lẻ. Nó nằm ở chỗ hệ số được dùng trong mô hình nào. Con số 0.82 là đúng nếu hiểu là tỉ số hiệu dụng, nhưng sẽ trừ tổn hao hai lần nếu đưa vào mô hình Mathavan. Đường fit μ(v) là đúng, nhưng chỉ khi tính theo tốc độ trượt tại điểm tiếp xúc và có trần 1/7; một cái sàn 0.05 đủ làm sai lệch throw ở cú nhanh. Vì vậy, bộ test có giá trị nhất là các đồng nhất thức: tách 90° khi không ma sát, gearing cho throw bằng 0, hướng massé không phụ thuộc μs, mô hình băng cứng bất biến theo tốc độ. Chúng bắt lỗi cấu trúc mà việc chỉnh hệ số không bao giờ bắt được.

Phía trước còn một giới hạn khách quan. Spin decay, e bi–bàn, hình dạng e_eff(v_n) của băng và quỹ đạo nhảy đều chưa có số đo công khai đáng tin. Mọi số liệu cho các đại lượng này trong app phải mang nhãn "giả định". Cách duy nhất để nâng chúng lên "đã đo" là tự quay video tốc độ cao, hoặc dùng các clip HSV của Dr. Dave (B.15, B.44) để fit. Hai nguồn khả dĩ cho các phần còn thiếu là TP B-10 và các bài BD về jump/massé trên colostate.edu, nhưng lần nghiên cứu này không truy cập được, nên đó là bước tiếp theo nên làm khi có thể.
