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

## Bản v5.0: nút đan chéo, móc 30°/2d, leader vuông góc

Sau APPLOAD, command line phải báo **rebar-detail v5.0**. Load / Reload Excel, bật Rebar draft, chọn **Rebar symbol = %%C (Diameter) hoặc T**, rồi Preview ở vùng trống.

### Cấu tạo nút theo hình mới

- Thép vế xiên và thép chiếu nghỉ/chiếu tới là **các thanh riêng**, có số hiệu riêng. Với hai lớp và cả hai chiếu nghỉ bật, có sáu tim thanh đại diện: hai vế xiên, hai chiếu nghỉ dưới và hai chiếu nghỉ trên.
- Các thanh đan sang lớp đối diện tại nút: lớp trên của vế xiên neo vào vùng lớp dưới chiếu nghỉ, lớp trên chiếu nghỉ đi vào vùng lớp dưới vế xiên; lớp dưới thực hiện tương ứng.
- Đoạn neo **200 mm cố định**, không nhân đường kính. Đối với vế xiên, đo 200 mm trên đoạn ngang vào chiếu nghỉ; đối với thanh chiếu nghỉ, đo 200 mm theo đoạn xiên vào vế thang. Không cộng đoạn đứng chuyển tiếp hoặc móc vào 200 mm này.
- Móc cuối dài **2 × đường kính thanh**, đang thể hiện là móc **quay ngược**, tạo góc nhọn 30° với hướng ngược của đoạn neo (đổi hướng 150°). Móc quay vào phía trong bê tông. Ví dụ d12: neo 200 mm, móc 24 mm; d14: neo vẫn 200 mm, móc 28 mm.
- Với nút nối liên tục, dùng giao điểm thật của tim xiên và tim ngang để tạo nút đan. Nếu kéo dài tim xiên như vậy sẽ ra ngoài bê tông do đoạn giật cấp, đường thanh giữ đoạn chuyển tiếp trong phần bê tông hiện có. Không thay đổi đường bao bê tông để ép thanh vào hình tham khảo.

**BJ38 đã được thay thế bởi quy tắc 200 mm này.** Ô vẫn được đọc để tương thích workbook, nhưng đổi 20/30d trong BJ38 không còn đổi chiều dài neo của v5.

Các đường thanh có thể giao nhau/trùng một phần trong hình chiếu tại nút đan. V5 cho phép giao nhau có chủ ý này, kiểm tra lớp ở phần thân bản, đồng thời kiểm tra từng đường thanh và móc nằm trong bê tông theo quy ước tim đã chốt. Nếu 200 mm hoặc móc 2d không đủ chỗ, tiện ích báo lỗi và giữ preview cũ; không tự cắt ngắn. Bán kính uốn và thống kê gia công chưa được tạo.

### Leader và ký hiệu thép

Leader là **LEADER loại đoạn thẳng** (AcLeaderType 0), gồm nhánh **đứng qua đúng điểm chỉ thanh/chấm**, rồi nhánh **ngang dưới text DK-KC**. Hai nhánh vuông góc; các nhánh đứng trong một cặp song song và tách nhau nhờ chọn hai vị trí chỉ khác nhau.

Ghi chú thép dọc và thép chấm của cùng vùng/lớp được đặt cùng cột text, thành hai hàng: lớp trên đặt phía trên bản, lớp dưới đặt phía dưới. Khoảng cách hàng có mức tối thiểu để vòng số hiệu không đè lên nhau. Đây là bố trí tự động cho mẫu hiện có, chưa phải thuật toán tránh tất cả va chạm với dim/đối tượng khác trong DWG.

- Thanh trong mặt cắt dùng **Architectural tick**; chấm thép dùng **Dot blank**.
- Kích thước đầu leader mặc định **100 mm / 60 mm** trong Model, chỉnh được trên UI.
- **Rebar symbol** chọn `%%C` hoặc `T`; ví dụ cùng dữ liệu `12a150` sẽ ghi `%%C12a150` (ký hiệu đường kính trong CAD) hoặc `T12a150`. Áp dụng cho cả ghi chú thanh và ghi chú thép chấm, không đổi font hoặc định nghĩa block CSA.
- Block ghi chú CSA hiện có vẫn làm Annotation của AddLeader, tránh lỗi tham số nil ở v4. Leader được đặt lại Type và tọa độ sau khi gán style/annotation.

### Nguồn thông số

| Ô | Dữ liệu sử dụng |
|---|---|
| `BJ28` | Khoảng cách biên tới tim thép dọc, không cộng d thép dọc/2 |
| `BJ29`, `BJ31` | Bề rộng vế/chiếu nghỉ; chưa suy số thanh toàn bộ mặt bằng |
| `BJ32`, `BJ33` | Đường kính/bước thép chiếu nghỉ dưới/trên |
| `BJ34`, `BJ35` | Đường kính/bước thép dọc dưới/trên của vế xiên |
| `BJ36` | Đường kính/bước thép cấu tạo vuông góc mặt cắt |
| `BJ37` | 1 hoặc 2 lớp; 1 lớp dựng một thanh thân dưới mỗi vùng, đầu neo vẫn theo cấu tạo nút |
| `BJ38` | Đọc để tương thích; **không điều khiển neo 200 mm trong v5** |
| `BJ39` | Số hiệu thanh bắt đầu; tăng liên tục cho các nhóm được vẽ |
| `BJ40`, `BJ41` | Đọc để mở rộng; chưa lập thống kê |
| `U28`, `AI23`, `AV21` | Nhãn số bậc đầu, số bậc vế xiên, chiều cao bậc đầu vào |
| `Z23`, `Z24` | Yes/No: thanh chiếu nghỉ trên/dưới |
| `Z25`, `Z26` | Yes/No: chấm thép cấu tạo chiếu nghỉ trên/dưới |

Chấm có đường kính thật BJ36, tim chấm cách biên `BJ28 + d cấu tạo/2`, bước đo dọc bản xiên hoặc ngang chiếu nghỉ. Với BJ28=25/d12: tim dọc cách biên 25, tim chấm 31 mm. Các nét vẫn dùng `18-GB-Reinf`; leader/ghi chú dùng `20-GB-GC`; block `CSA_Sohieu-KCthep` giữ scale 1.0.

### Các bản sửa trước được giữ

- Chân dim cố định **150 mm trong Model**, dùng DIMOVERRIDE gộp theo scale cho dim mới; không tự ghi DSTYLE xdata, không chọn dim cũ hoặc sửa định nghĩa DimStyle. Có bù DIMSCALE như bản v4.3 người dùng đã chạy được.
- Scale Cao do 0.25, Daucat 0.01, So hieu thep 0.35; các dim đánh X vẫn được bỏ.
- Preview được đánh dấu và chỉ thay sau khi dựng thành công; các bản chính thức cũ không tự cập nhật.
- V5 **tách nhãn số bậc khỏi chiều cao giật cấp**. U28/AI23 phải là số nguyên hợp lệ, AV21 phải dương; không còn buộc giật đầu dưới bằng U28 × AV21. Vì vậy nút 0 mm không bị chặn chỉ vì ô nhãn còn 2 bậc. Đường bao, chiều dày và cao độ vẫn được kiểm tra riêng theo dữ liệu Excel. V5 chỉ ghi số bậc, chưa dựng răng cưa từng bậc.

### Kiểm tra trong AutoCAD

1. APPLOAD, xác nhận **v5.0**, rồi Load / Reload Excel.
2. Chọn Rebar symbol, bật Rebar draft và Preview tại vùng trống.
3. Zoom cả hai nút: các thanh phải tách riêng, đan sang lớp đối diện; đo đoạn neo **200 mm** và móc **2d**. Góc nhọn móc với thân là 30° theo cách thể hiện ở trên.
4. Kiểm tra nhánh đứng của từng cặp leader song song, nhánh ngang vuông góc và nằm dưới text. Chọn lại `T`/`%%C`, Preview lần nữa để kiểm tra nội dung.
5. Kiểm tra tim dọc/chấm, các lựa chọn Yes/No, lớp thép và số hiệu từ Excel; đo chân dim vẫn 150 mm.
6. Draw Section tại điểm mới khi đã kiểm tra. Môi trường Linux chưa chạy AutoCAD; kiểm tra offline không xác nhận hiển thị COM/DCL thực tế.

## Kiểm tra mã nguồn

Đã kiểm tra tên layer/tag với CSV gốc và thực thi các helper xử lý tọa độ/định dạng bằng evaluator giới hạn cho hàm thuần. Bộ kiểm tra dùng chính 24 dòng tọa độ được lưu trong workbook. Chưa thực thi COM Excel, DCL hoặc dựng entity trong AutoCAD từ môi trường Linux.

Nguồn UI ở `../ui/CSA_StairDrawing.core.lsp`, planner dimension ở `../ui/CSA_StairConcreteDetails.lsp`, tim thép ở `../ui/CSA_StairRebar.lsp`; bản một file được tạo bằng `python3 stair-tool/tools/build_stair_bundle.py`. Không sửa trực tiếp file gộp. Chạy `python3 -m unittest discover -s stair-tool/tests -v` để kiểm tra.

Khi nạp đè bản cũ, cần bấm **Load / Reload Excel một lần** để có thêm thông số cấu tạo. Các bản vẽ chính thức cũ không tự cập nhật; chọn một điểm mới để so sánh. Tên phiên bản xuất ở command line là **rebar-detail v5.0**.
