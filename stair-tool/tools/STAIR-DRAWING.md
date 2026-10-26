# CSA Stair Drawing — giao diện và mặt cắt từ Excel

## Bản chạy một file

Tải `CSA_StairDrawing.lsp` tại thư mục này. File đã gộp toàn bộ helper cần thiết, không cần tải Lisp/DCL khác hoặc import VBA. Đây là giao diện DCL chạy trong AutoCAD Windows, chưa phải file `.dvb` hoặc UserForm đã đóng gói.

1. Mở **bản sao** `CSA Drawing Data.Rev12.dwg` (file mẫu ở nhánh `main`), vào tab Model. Đơn vị `INSUNITS=4` (mm).
2. Mở `CSA_Stair Drawing Tools.xlsm` trong Excel, kiểm tra sheet `Cau Thang Tools` đã tính ra tọa độ. Chờ Excel tính xong.
3. `APPLOAD` file **`CSA_StairDrawing.lsp`**.
4. Gõ **`CSA_STAIR_DRAWING`**.
5. Bấm **Load / Reload Excel**, chọn đúng file `.xlsm` đang mở. Trạng thái báo số dòng và số đỉnh sau khi loại các điểm trùng liên tiếp.
6. Chọn DimStyle **GB 25**, kiểm tra tên cầu thang, mã mặt cắt và hai cao độ. Với dữ liệu trong repository: cao độ dưới **+0.050 m**, trên **+2.250 m**. Bật **Concrete details** và **Step counts from Excel**; thử **Title height = 200 mm**, **Dimension spacing = 400 mm**.
7. Bấm **Preview**, chọn điểm chèn trong vùng trống. Hộp thoại đóng để bạn có thể zoom/pan kiểm tra hình thật.
8. Gõ lại **`CSA_STAIR_DRAWING`** để mở giao diện với dữ liệu đã nạp. Bấm **Draw Section**, chọn điểm chèn bản vẽ chính thức.
9. Preview được xóa sau khi xuất thành công. Để chỉ xóa preview, mở lại giao diện và bấm **Clear Preview**.

Sau khi thay đổi Excel phải bấm **Load / Reload Excel**; không có đồng bộ nền. Nút Close chỉ đóng giao diện, không tự xóa preview để người dùng kiểm tra ngoài viewport. Khi đổi DWG, dữ liệu Excel đã nạp vẫn có thể dùng, nhưng tài nguyên và đơn vị của DWG đích được kiểm tra lại trước mỗi lần vẽ.

## Cập nhật v5.4

- Chân dim cố định **200 mm**, hàng dim ngang trên cách mặt bản trên **775 mm**. Ô Dimension spacing tiếp tục điều khiển các khoảng dim khác.
- Bỏ nhãn BAC độc lập; dim ngang vế xiên ghi **số bậc × bề rộng bậc = tổng đo thật**. Ví dụ hình chiếu 2500 mm, 13 bậc: `13 x 192.31 = 2500`. Bề rộng biểu diễn làm tròn 2 số lẻ; `<>` trong TextOverride giữ giá trị đo thật. Khi tắt Concrete details nhưng bật Step count, vẫn tạo riêng dim này.
- Ghi chú lớp trên của chiếu nghỉ/chiếu tới ở bên trái, lớp dưới ở bên phải, vòng SH ngoài cùng và chữ đọc thuận.
- Sửa AcLeaderType thành **2 = Line with arrow**. Giá trị 0 của bản cũ là Line with no arrow: Arrow size lớn vẫn không hiện tick/dotblank. Các mũi dùng ArchTick/DotBlank, kích thước Model theo UI.
- Hai đường chuẩn cao độ ngang trải từ mép trái−500 đến mép phải+500 mm; hai block Cao do cùng cột bên phải, tại đúng cao độ mặt bản dưới/trên. Dùng layer cao độ có sẵn; chưa bổ sung bong bóng tên trục vì hình không yêu cầu tên trục.
- Tại nút nối bản không dầm, neo ngang thép xiên lớp trên cách tim thép ngang **lớp dưới +10 mm**, lớp dưới trùng tim đó. Neo của thép ngang vào vế xiên cùng tham chiếu **lớp dưới vế xiên**: lớp trên cách vào trong 10 mm theo phương vuông góc, lớp dưới trùng tim.
- Folder Excel được lưu sau lần Load thành công bằng thiết lập `CSA_STAIR_EXCEL_FOLDER` và dùng lại khi mở hộp chọn file, kể cả phiên AutoCAD sau. Cancel/Load lỗi không ghi đè folder đã lưu.

APPLOAD bản **v5.4**, Reload Excel, tạo Preview mới. Kiểm tra Properties leader phải là **Line with arrow**, dim trên 775 mm và chân dim 200 mm. Các đối tượng đã vẽ bằng bản cũ không tự cập nhật.

## Sửa lỗi v5.3.1: bad function 120.0

Bản v5.3 dùng tham số `length` trùng hàm AutoLISP `LENGTH` trong ba helper neo. Với BJ38=10, d12, giá trị neo là 120.0. Khi hàm con gọi LENGTH, AutoCAD cố gọi số 120.0 như hàm và dừng ở Section preflight. Đây là lỗi mã, không phải lỗi ô số bậc 0.

v5.3.1 đổi tham số sang `embedment-mm`, đồng thời đổi biến tương tự trong planner dim. Bộ kiểm tra offline đã bổ sung phát hiện va chạm tên hàm/biến qua phạm vi động. Nạp lại file bằng APPLOAD, xác nhận **v5.3.1**, rồi Reload Excel và Preview. Nếu cần, mở lại AutoCAD trước khi nạp bản mới để tránh trạng thái symbol của Lisp cũ.

Sau sửa, chiều dài 10d=120 mm vẫn phải đạt kiểm tra hình học neo riêng; bản sửa không tăng/giảm giá trị Excel để ép vẽ.

## Bản v5.3 — neo Excel và cổ thang

Neo dùng **BJ38 × đường kính từng thanh**, thay quy tắc 200 mm. Neo trong dầm đo dọc tim thanh **từ mặt dầm tới đầu neo**, gồm đoạn đi vào và đoạn đứng; không tính móc 2d hay phần đi qua cổ ngoài dầm. Xem quy tắc chi tiết và cách kiểm tra bên dưới.

Đầu ngoài chiếu nghỉ/chiếu tới không có dầm: thanh trên tới đường cách mép bê tông BTBV rồi bẻ xuống tim thanh dưới; thanh dưới dừng cách mép bê tông **BTBV + 20 mm**. Mỗi đầu được nhận diện riêng, độc lập với dầm tại nút nối bản xiên.

Đây là bản Lisp chạy được để thử chi tiết. Chưa có binary `.dvb`; việc đóng gói và kiểm tra VBA cần AutoCAD VBA Windows.

## Scale đã chốt từ hình người dùng

| Block | Scale X/Y/Z |
|---|---:|
| `Cao do` | **0.25** |
| `Daucat` | **0.01** |
| `So hieu thep` | **0.35** |
| `CSA_Sohieu-KCthep` | **1.0**, giữ nguyên như mẫu không có ghi chú đổi scale |

Các mặc định này áp dụng cho template và mẫu GB 25 đã chốt; không tự nhân theo mẫu số tỷ lệ của DimStyle khác. `CSA_STAIR_TEST` trong cùng file cũng dùng các scale cố định này để có thể kiểm tra lại bộ ký hiệu.

### Sửa lỗi scale trong bản concrete-details v2

Ảnh người dùng cho thấy `Daucat` khai báo Inches, Unit factor 25.4 và scale tham chiếu khoảng 0.0003, dù giá trị truyền cho InsertBlock là 0.0075. Bản mới đọc lại `XScaleFactor` sau khi chèn, dùng `ScaleEntity` để đưa scale tham chiếu về đúng mức đã chốt và kiểm tra cả ba trục. Phép biến đổi đi cùng các attribute; không đổi `INSUNITS`, định nghĩa block hoặc các block cũ.

Khi kiểm tra lại, **Properties của block Daucat mới phải có Scale X/Y/Z = 0.01**, vẫn có thể giữ Block Unit = Inches và Unit factor = 25.4. Nếu khác, gửi ảnh Properties mới; phần COM này cần xác nhận trong AutoCAD, không thể chứng minh bằng kiểm tra trên Linux.

## Giao diện hiện thực hiện được

- Chọn Excel bằng hộp thoại file, không phải gõ đường dẫn.
- Chọn DimStyle từ danh sách của DWG đích.
- Tên cầu thang, mã mặt cắt, cao độ, chiều cao tên và khoảng cách các hàng dim có thể chỉnh trên giao diện.
- Đọc đường bao bê tông từ Excel; loại điểm liên tiếp trùng nhau và điểm đóng cuối trùng đầu.
- Preview bằng polyline kín, kèm tùy chọn kích thước tổng thể, **dimension cấu tạo bê tông**, cao độ và ký hiệu mặt cắt.
- Tên cầu thang căn giữa dưới đường bao, tách khỏi chiều cao chữ DimStyle; bên dưới là cụm **MAT CAT + block Daucat**. Các thành phần được căn theo bounding box sau khi block đã được hiệu chỉnh scale.
- Xuất cùng đường bao sang `21-GB-BD`; kích thước sang `04-GB-Dim`; chữ sang `10-GB-Text`; cao độ sang `11-GB-Cao Do`; ký hiệu sang `12-GB-Ky Hieu`.
- Các đối tượng gốc của preview nằm trên `CSA-PREVIEW` và được đánh dấu riêng. Block vẫn giữ layer/thuộc tính của các entity nội bộ theo định nghĩa CSA.
- Chỉ tạo `CSA-PREVIEW` nếu thiếu, đặt non-plot cho layer vừa tạo. Giữ nguyên các layer, block và style có sẵn.
- Mỗi lần xuất chính thức tạo một nhóm hình mới tại điểm chèn, không tự sửa hoặc xóa bản vẽ chính thức cũ. Dùng UNDO nếu cần hoàn tác lần xuất.

## Hợp đồng dữ liệu bê tông đang dùng

Nguồn duy nhất ở vòng này là sheet **`Cau Thang Tools`**. Không tự nối dữ liệu khác nghĩa trong `3-SIDES`.

| Vùng | Ý nghĩa |
|---|---|
| `BY2:BY500` | STT, dừng khi gặp ô trống |
| `BZ2:BZ500`, `CA2:CA500` | Tọa độ X/Y theo mm |
| `D22` | Chênh cao sàn, mm |
| `M30` | Cao độ sàn dưới, m |
| `AD33` | Tên cầu thang |
| `H19`, `Z19`, `BA19` | Chiều dài chiếu nghỉ dưới, hình chiếu vế xiên, chiếu tới |
| `D31`, `D33` | Chiều dày bản dưới và phần dầm nhô dưới bản |
| `BU21`, `BU22` | Chiều dày bản trên và phần dầm nhô dưới bản |
| `AO27` | Chiều dày bản xiên đo vuông góc |

Trong workbook hiện tại, tọa độ đầu là mốc sàn dưới; điểm có Y lớn nhất là mốc sàn trên. Chênh cao phải khớp `D22`. Nếu file khác thay đổi ý nghĩa này, tiện ích báo lỗi thay vì tự đoán. Khi nhập cao độ trên giao diện, chênh lệch cũng phải khớp hình học trong sai số 0.5 mm.

**Overall width** chỉ vẽ tổng ngang 6500 theo hình người dùng. Đã bỏ 5 dim đánh X: tổng cao dầm dưới 400, tổng cao dầm trên 400, lọt lòng dưới 1700, lọt lòng trên 1100 và tổng cao bao 2600. Hình học bê tông không thay đổi; vẫn giữ chênh cao sàn 2200, các dim 120/280 và bề rộng các gối.

### Dimension cấu tạo bê tông

Bản hiện tại giữ riêng 24 điểm gốc theo STT trước khi loại trùng để nhận diện các chi tiết trong mẫu Excel. Với dữ liệu gốc, bật Concrete details sẽ tạo 15 dimension:

| Nhóm | Kích thước mẫu (mm) |
|---|---|
| Chuỗi ngang phía trên | 2000 / 3000 / 1500 |
| Chênh cao sàn | 2200 |
| Bản dưới / dầm nhô dưới bản | 120 / 280 |
| Bề rộng gối dưới | 200 và 250; không còn dim 1700 |
| Bản trên / dầm nhô dưới bản | 120 / 280 |
| Bề rộng gối trên | 200 và 200; không còn dim 1100 |
| Chênh cao đầu/cuối đoạn xiên | 314.286 / 157.143, hiển thị theo độ chính xác DimStyle |
| Bản xiên | 120, **đo vuông góc** giữa hai biên |

Các số là số đo hình học, không ghi đè text dimension. Dimension ngang/đứng dùng `AddDimRotated`; chiều dày bản xiên dùng `AddDimAligned` sau khi chiếu vuông góc. Đoạn có kích thước bằng 0 được bỏ qua, không tạo dim rỗng. Khi thông số Excel không khớp đường bao trong sai số 0.5 mm, hoặc hai biên xiên không song song, chương trình báo lỗi trước khi dựng hình mới. Tắt Concrete details nếu chỉ cần đường bao từ một workbook khác không theo hợp đồng 24 điểm này.

Các dim 314/157 là chênh cao hình học ở hai đầu bản xiên. Số bậc được ghi riêng từ U28/AI23; bản này chưa dựng đường răng cưa từng bậc trên biên bê tông.

Excel được **kết nối vào phiên đang chạy**. Tiện ích không tạo/đóng Excel, không ghi ô, không tự bật macro hay tính lại workbook. Nếu có nhiều phiên Excel, hãy mở workbook trong phiên mà AutoCAD kết nối được; thông báo sẽ chỉ rõ nếu không tìm thấy file đang mở. Ô Excel lỗi, dữ liệu không hợp lệ hoặc đường bao suy biến sẽ bị từ chối trước khi thay dữ liệu đã nạp.

## Kiểm tra nghiệm thu vòng này

Gửi ảnh gồm giao diện sau Load Excel và mặt cắt sau Preview/Draw Section. Kiểm tra:

1. Đường bao khớp hình trong workbook, giữ đúng gối/dầm và chiều dày.
2. Cao độ hiển thị ba số lẻ, đúng vị trí và scale 0.25.
3. Tên cầu thang và cụm MAT CAT căn giữa dưới hình, đủ lớn với Title height 200. Ký hiệu mặt cắt có scale tham chiếu 0.01; kích thước dùng GB 25.
4. Có các chuỗi kích thước cấu tạo như bảng trên; bản xiên đo được 120, không phải khoảng cách đứng giữa hai biên.
5. Preview lặp lại không chồng hình; Clear Preview giữ nguyên hình chính thức và các đối tượng khác trên cùng layer.
6. Khi Excel đang có lỗi hoặc tài nguyên CSA thiếu/khóa, có thông báo và không xuất hình dở dang mới.

Nút **Plan (next phase)** được vô hiệu hóa: bảng tọa độ đang có là đường bao mặt cắt, chưa chứa dữ liệu mặt bằng 2 vế/3 vế. Đã có tùy chọn tim thép dọc và thép chiếu nghỉ ở giai đoạn kiểm tra, chưa có thống kê hoặc móc/uốn hoàn chỉnh. Không lấy các thanh mẫu ở tiện ích kiểm tra để thay cho thiết kế. Bản này chưa triển khai toàn bộ cầu thang 2/3 vế.

## Cấu tạo thép v5.3

Sau APPLOAD, command line phải báo **rebar-detail v5.4**. Load / Reload Excel, bật Rebar draft, chọn **Rebar symbol = %%C (Diameter) hoặc T**, rồi Preview tại vùng trống.

### Neo nối bản và neo vào dầm

- `BJ38` là hệ số neo theo đường kính, phải là số dương. Ví dụ BJ38=30: thanh d12 neo 360 mm, d14 neo 420 mm. Chiều dài được dùng thống nhất khi kiểm tra, dựng thanh và đặt leader.
- **Nút không có dầm:** đoạn neo ngang của thép xiên lớp trên cao hơn tim thép ngang lớp dưới 10 mm; neo ngang của thép xiên lớp dưới trùng **tim thép ngang lớp dưới**. Đoạn ngang dài BJ38 × d, chưa cộng móc và đoạn chuyển tiếp qua cổ.
- Thép bản ngang vẫn là thanh riêng: lớp trên kéo vào vùng lớp dưới vế xiên, cách tim lớp dưới 10 mm theo phương vuông góc; lớp dưới trùng tim lớp dưới vế xiên. Các đoạn xiên cũng dài BJ38 × d. Quy tắc này giữ từ bản đã chốt; xác nhận mới thay vị trí **neo ngang của thép vế xiên**.
- **Dầm trên:** cả hai lớp thép vế xiên tiến tới đường cách mép dầm BTBV rồi bẻ lên. **Dầm dưới:** bẻ xuống. Tổng chiều dài nằm trong dầm bằng BJ38 × d; chiều dài đoạn đứng là phần còn lại sau đoạn đi vào dầm.
- Nếu cổ cao làm đường kéo tới phía xa đi ra ngoài bê tông, đoạn đứng ở dầm dưới đi theo đường BTBV phía gần vế xiên. Chiều dài xuyên cổ **ngoài dầm** không được tính vào neo: bắt đầu đếm ở mặt trên dầm. Dầm được giới hạn bởi bề rộng thực tế, đáy dầm và mặt trên bản ngang trong hợp đồng tọa độ hiện tại.
- Thép lớp dưới bản ngang tại đầu có dầm đi vào tới đường BTBV phía đối diện rồi bẻ xuống. Phần ngang trong dầm cộng phần đứng bằng BJ38 × d.
- Móc cuối vẫn quay ngược **30°**, dài **2d**, không cộng vào chiều dài neo. Móc hướng vào bê tông; không tự rút ngắn khi thiếu chỗ.
- Tự nhận dầm ở từng nút theo bề rộng và phần nhô xuống >0,5 mm. Dầm dưới dùng STT 18/19/20; dầm trên dùng STT 11/12/10. Dầm mép ngoài được nhận diện riêng. Không suy ra dầm chìm không thể hiện trong đường bao.

Nếu chiều dài/móc không đặt vừa, chương trình báo đầu trên/dưới, lớp thanh và chiều dài yêu cầu trước khi tạo hình; giữ preview trước đó. Với **workbook mẫu nguyên trạng trong kho**, dầm trên rộng 200 mm không đủ chỗ cho neo hướng lên 30d của thanh d12 với BTBV 25 mm. Cần kiểm tra cấu tạo và dữ liệu thực tế; công cụ không sửa Excel hoặc tự giảm BJ38.

### Cổ thang và đai bo góc

Chỉ bố trí khi **không có dầm tại nút** và chiều cao cổ **lớn hơn 100 mm** (đúng 100 mm không bố trí). Chiều cao cổ dưới lấy STT 3−2 theo Y; cổ trên lấy STT 5−4 theo Y. Nút không đạt điều kiện vẫn có neo thép dọc theo hình học bản/dầm hiện có.

- Một đai chữ nhật bo góc đại diện trong mặt cắt, ghi **Ø8a200**. Tim đai cách biên BTBV + 4 mm, bo theo tim **R4 mm** như bán kính thanh góc Ø8 được chốt. Polyline kín dùng bốn cung tròn 90°, không dùng spline.
- **4 thanh góc Ø8**, biểu diễn bằng bốn chấm, ghi **4Ø8** (hoặc 4T8). Chấm vẫn phóng 1,5 lần để đọc rõ, tâm được đặt để chấm nằm trong đai; đường kính ghi chú vẫn Ø8.
- Số hiệu tiếp nối các nhóm thép đã vẽ. Đai dùng leader Architectural tick, thanh góc dùng Dot blank, block/tag/font như các ghi chú thép khác.
- Kiểm tra kích thước cổ, lớp bảo vệ và chỗ cho bốn chấm. Không ép đai/chấm ra ngoài bê tông để đủ số lượng. a200 là bước ghi chú theo cấu tạo đã chốt; chưa dựng mặt bằng số lượng đai hay bảng thống kê.

### Các thiết lập trình bày được giữ

Ghi chú lớp dưới vế xiên đặt sang phải, vòng SH ngoài cùng bên phải và chữ đọc thuận. Tâm chấm cách tim thép dọc bằng bán kính hiển thị `1,5 × d/2`. Ví dụ d10 hiển thị đường kính 15 mm, cách tim thép dọc 7,5 mm. Ghi chú vẫn dùng đường kính/bước thật.

Thép dọc đặt theo BTBV đã chốt trong hình biểu diễn tim; các đường thanh có thể giao nhau trong hình chiếu. Bán kính gia công thanh dọc và thống kê cắt/uốn chưa được tạo; R4 ở trên chỉ áp dụng đai cổ thang.

### Leader và ký hiệu thép

Leader là **LEADER loại đoạn thẳng** (AcLeaderType 2), gồm nhánh **đứng qua đúng điểm chỉ thanh/chấm**, rồi nhánh **ngang dưới text DK-KC**. Hai nhánh vuông góc; các nhánh đứng trong một cặp song song và tách nhau nhờ chọn hai vị trí chỉ khác nhau.

Ghi chú thép dọc và thép chấm của cùng vùng/lớp được đặt cùng cột theo mép text phía nhánh đứng, thành hai hàng: lớp trên đặt phía trên điểm chỉ, lớp dưới đặt phía dưới. Khoảng cách đường ngang cố định 200 mm như phần trên; AutoCAD lấy bounding box sau khi đặt font để căn đúng các đường ngang. Đây là bố trí cho mẫu hiện có, chưa phải thuật toán tránh mọi va chạm với các đối tượng khác trong DWG.

- Thanh trong mặt cắt dùng **Architectural tick**; chấm thép dùng **Dot blank**.
- Kích thước đầu leader mặc định **100 mm / 60 mm** trong Model, chỉnh được trên UI.
- **Rebar symbol** chọn `%%C` hoặc `T`; ví dụ cùng dữ liệu `12a150` sẽ ghi `%%C12a150` (ký hiệu đường kính trong CAD) hoặc `T12a150`. Áp dụng cho cả ghi chú thanh và ghi chú thép chấm. DK-KC của ghi chú mới dùng Arial; định nghĩa block CSA được giữ nguyên.
- Block ghi chú CSA hiện có vẫn làm Annotation của AddLeader, tránh lỗi tham số nil ở v4. Leader được đặt lại Type 2 và tọa độ sau khi gán style/annotation.

### Nguồn thông số

| Ô | Dữ liệu sử dụng |
|---|---|
| `BJ28` | Khoảng cách biên tới tim thép dọc, không cộng d thép dọc/2 |
| `BJ29`, `BJ31` | Bề rộng vế/chiếu nghỉ; chưa suy số thanh toàn bộ mặt bằng |
| `BJ32`, `BJ33` | Đường kính/bước thép chiếu nghỉ dưới/trên |
| `BJ34`, `BJ35` | Đường kính/bước thép dọc dưới/trên của vế xiên |
| `BJ36` | Đường kính/bước thép cấu tạo vuông góc mặt cắt |
| `BJ37` | 1 hoặc 2 lớp; 1 lớp dựng một thanh thân dưới mỗi vùng, đầu neo vẫn theo cấu tạo nút |
| `BJ38` | Hệ số neo: chiều dài = BJ38 × đường kính từng thanh; chưa tính móc 2d |
| `BJ39` | Số hiệu thanh bắt đầu; tăng liên tục cho các nhóm được vẽ |
| `BJ40`, `BJ41` | Đọc để mở rộng; chưa lập thống kê |
| `U28`, `AI23`, `AV21` | Nhãn số bậc đầu, số bậc vế xiên, chiều cao bậc đầu vào |
| `Z23`, `Z24` | Yes/No: thanh chiếu nghỉ trên/dưới |
| `Z25`, `Z26` | Yes/No: chấm thép cấu tạo chiếu nghỉ trên/dưới |

Chấm hiển thị có đường kính 1,5 × BJ36; tim chấm cách biên `BJ28 + 1,5 × d cấu tạo/2`. Bước đo dọc bản xiên hoặc ngang chiếu nghỉ. Với BJ28=25/d12: tim dọc cách biên 25, tim chấm 34 mm. Các nét vẫn dùng `18-GB-Reinf`; leader/ghi chú dùng `20-GB-GC`; block `CSA_Sohieu-KCthep` giữ scale 1.0.

### Các bản sửa trước được giữ

- Chân dim cố định **200 mm trong Model**, dùng DIMOVERRIDE gộp theo scale cho dim mới; không tự ghi DSTYLE xdata, không chọn dim cũ hoặc sửa định nghĩa DimStyle. Có bù DIMSCALE như bản v4.3 người dùng đã chạy được.
- Scale Cao do 0.25, Daucat 0.01, So hieu thep 0.35; các dim đánh X vẫn được bỏ.
- Preview được đánh dấu và chỉ thay sau khi dựng thành công; các bản chính thức cũ không tự cập nhật.
- V5 **tách nhãn số bậc khỏi chiều cao giật cấp**. U28/AI23 phải là số nguyên hợp lệ, AV21 phải dương; không còn buộc giật đầu dưới bằng U28 × AV21. Vì vậy nút 0 mm không bị chặn chỉ vì ô nhãn còn 2 bậc. Đường bao, chiều dày và cao độ vẫn được kiểm tra riêng theo dữ liệu Excel. V5 chỉ ghi số bậc, chưa dựng răng cưa từng bậc.

### Kiểm tra trong AutoCAD

1. APPLOAD, xác nhận **v5.4**, rồi Load / Reload Excel.
2. Chọn Rebar symbol, bật Rebar draft và Preview tại vùng trống.
3. Kiểm tra Beam supports. Đo tổng tim thanh trong dầm tới đầu neo bằng BJ38 × d, bỏ phần xuyên cổ ngoài dầm và móc 2d. Dầm trên: thép vế xiên bẻ lên; dầm dưới: bẻ xuống. Kiểm tra từng đầu có/không dầm.
4. Tại nút nối bản không dầm, neo ngang lớp trên cao hơn tim thép ngang lớp dưới 10 mm; neo ngang lớp dưới trùng tim đó. Kiểm tra cổ >100 mm có đai R4, ghi Ø8a200 và 4Ø8; cổ ≤100 mm hoặc có dầm không có bộ thép này.
5. Cụm ký hiệu lớp dưới FLIGHT phải ở bên phải nhánh đứng, vòng SH ngoài cùng bên phải, chữ không ngược. Kiểm tra các khoảng cách leader vẫn là 200–200–50 mm và lựa chọn T/%%C.
6. D10 phải hiển thị chấm 15 mm và tâm cách đường thép dọc 7,5 mm, ghi chú vẫn d10. Kiểm tra các lựa chọn Yes/No, lớp thép, số hiệu; chân dim bê tông 200 mm.
7. Draw Section tại điểm mới khi đã kiểm tra. Môi trường Linux chưa chạy AutoCAD; kiểm tra offline không xác nhận hiển thị COM/DCL thực tế.

## Kiểm tra mã nguồn

Đã kiểm tra tên layer/tag với CSV gốc và thực thi các helper xử lý tọa độ/định dạng bằng evaluator giới hạn cho hàm thuần. Bộ kiểm tra dùng chính 24 dòng tọa độ được lưu trong workbook. Chưa thực thi COM Excel, DCL hoặc dựng entity trong AutoCAD từ môi trường Linux.

Nguồn UI ở `../ui/CSA_StairDrawing.core.lsp`, planner dimension ở `../ui/CSA_StairConcreteDetails.lsp`, tim thép ở `../ui/CSA_StairRebar.lsp`; bản một file được tạo bằng `python3 stair-tool/tools/build_stair_bundle.py`. Không sửa trực tiếp file gộp. Chạy `python3 -m unittest discover -s stair-tool/tests -v` để kiểm tra.

Khi nạp đè bản cũ, cần bấm **Load / Reload Excel một lần** để có thêm thông số cấu tạo. Các bản vẽ chính thức cũ không tự cập nhật; chọn một điểm mới để so sánh. Tên phiên bản xuất ở command line là **rebar-detail v5.4**.
