# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder bên dưới bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Đặng Hữu Cương  Mã học viên: 2A202602572

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> **Tình huống cụ thể:**
> - Nếu để mặc định `agent_api_key="changeme"`: Khi deploy ứng dụng lên môi trường production mà kỹ sư vô tình quên cấu hình biến môi trường `AGENT_API_KEY`, ứng dụng vẫn âm thầm khởi động bình thường và báo liveness probe 200 OK.
> - Hậu quả là:
>   1. Các bot/scanner trên Internet liên tục dò quét các endpoint với khóa mặc định (`changeme`, `admin`, `secret`) sẽ dễ dàng vượt qua cổng xác thực của `/ask`, liên tục gọi model và làm cạn kiệt ngân sách hóa đơn API LLM.
>   2. Trong khi đó, các client hợp lệ của hệ thống dùng key bảo mật thật lại liên tục bị từ chối với lỗi `401 Unauthorized`.
> - **Cơ chế Fail-fast cứu nguy:** Nhờ không đặt giá trị mặc định, Pydantic BaseSettings sẽ lập tức tung ngoại lệ `ValidationError` ngay tại thời điểm import/khởi động app. Tiến trình dừng ngay lập tức (exit code != 0), nền tảng cloud (Render/K8s) nhận diện deployment thất bại và dừng rollback trước khi cho phép bất kỳ traffic nào đi vào, buộc dev phải cấu hình đúng key bí mật trước khi service hoạt động.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> - **Dòng log JSON thu được:**
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T10:57:01.591171+00:00", "user_id": "sv-test", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
> ```
> - **Hai việc làm được với dòng log này mà `print("đã trả lời xong")` không làm được:**
>   1. **Truy vấn và lọc dữ liệu có cấu trúc (Structured Querying & Tracing):** Các hệ thống giám sát tập trung (Datadog, Grafana Loki, CloudWatch, ELK) có thể tự động bóc tách (parse) từng trường JSON theo kiểu dữ liệu. Nhờ đó, kỹ sư có thể dễ dàng truy vấn: lọc tất cả request của một người dùng cụ thể (`user_id = 'sv-test'`), hoặc tìm các request tốn kém bất thường (`cost_usd > 0.05`). Dòng `print` text thô không thể lọc được theo trường nếu không viết regex phức tạp và dễ gãy vỡ.
>   2. **Tổng hợp số liệu & thiết lập cảnh báo tự động (Metrics Aggregation & Alerting):** Các hệ thống APM có thể bóc tách giá trị số từ trường `cost_usd`, `tokens_in`, `tokens_out` để vẽ biểu đồ chi phí thời gian thực theo từng phút/giờ, và tự động kích hoạt cảnh báo (Alert PagerDuty/Slack) ngay khi tổng chi phí token của hệ thống vượt ngưỡng định mức trong 5 phút. `print` text vô định hình hoàn toàn không thể làm đầu vào cho các thuật toán phân tích số liệu tự động.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```


| Bản                 | Dung lượng |
| -------------------- | ------------ |
| 1 stage (bản đầu) | 1.73 GB (1730 MB) |
| Multi-stage          | 271 MB       |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần dung lượng chênh lệch chủ yếu gồm:
> 1. Sự khác biệt giữa base image: `python:3.11` đầy đủ chứa toàn bộ hệ điều hành Debian với trình biên dịch C/C++ (gcc, g++, make), build tools, thư viện dev và các gói tiện ích không cần thiết; trong khi `python:3.11-slim` đã loại bỏ hoàn toàn các thành phần này.
> 2. Cơ chế Multi-stage build tách biệt giai đoạn build và runtime: các công cụ cài đặt, file tạm thời, và cache của pip chỉ nằm ở stage `builder`, chỉ có kết quả packages đã hoàn thiện (`/install`) được copy sang stage `runtime`.
> 3. File rác và cache cục bộ được loại bỏ nhờ `.dockerignore` chặt chẽ, không bị lọt vào layer image cuối cùng.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> - **Khi sửa 1 ký tự trong `app/main.py` với Dockerfile hiện tại:**
>   - **Layer được dùng lại từ cache:** Tất cả các layer của stage `builder` (chuẩn bị wheels/pip install) và các layer đầu của stage `runtime` gồm base image, tạo user `appuser`, và `COPY --from=builder /install /usr/local`. Do `requirements.txt` không thay đổi, Docker nhận diện mã hash layer không đổi và tái sử dụng toàn bộ cache thư viện đã cài đặt.
>   - **Layer phải chạy lại:** Chỉ có layer `COPY app/ ./app/` và các chỉ thị bên dưới nó (`USER appuser`, `EXPOSE`, `CMD`). Thời gian build lại diễn ra gần như tức thì (< 1 giây).
> - **Nếu đặt `COPY . .` lên trước `RUN pip install`:**
>   - Bất cứ khi nào sửa dù chỉ 1 ký tự trong source code, cache của layer `COPY . .` bị vô hiệu hóa (cache bust).
>   - Kéo theo đó, tất cả các layer đứng sau nó đều bị hủy cache, buộc lệnh `RUN pip install` phải tải lại và cài đặt lại toàn bộ packages từ PyPI từ đầu.
>   - Kết quả: Mỗi lần sửa code nhỏ nhặt đều mất vài phút để build lại, tiêu tốn băng thông mạng và làm chậm nghiêm trọng quy trình CI/CD. Đặt `COPY requirements.txt` và `RUN pip install` lên trước `COPY code` là nguyên tắc tối ưu hóa layer caching cốt lõi của Docker.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> - **Chuỗi sự kiện dẫn từ lỗ hổng code đến chiếm quyền máy host:**
>   1. Kẻ tấn công phát hiện một lỗ hổng thực thi mã từ xa (RCE) trong code Python (ví dụ: hàm `eval()`, lỗ hổng command injection, hoặc thư viện phụ thuộc chứa CVE độc hại).
>   2. Kẻ tấn công gửi payload khai thác thành công và chiếm được shell điều khiển bên trong container.
>   3. Do container mặc định không khai báo `USER`, tiến trình Python chạy với quyền `root` (`UID 0`) bên trong container namespace.
>   4. Khi đã là `root` trong container, kẻ tấn công có thể khai thác các cấu hình mount nguy hiểm (ví dụ mount nhầm Docker socket `/var/run/docker.sock`, mount thư mục `/etc` hoặc volume của host) hoặc khai thác lỗ hổng bảo mật của Linux Kernel (Container Escape như Dirty COW, CVE của runc/containerd) để bẻ gãy ranh giới cô lập (sandbox) của container.
>   5. Do Linux kernel trên host ánh xạ trực tiếp `UID 0` của container với `root (UID 0)` của máy host, kẻ tấn công sau khi thoát khỏi container sẽ lập tức có toàn quyền `root` tối cao trên máy host, cho phép đọc trộm dữ liệu, cài mã độc vĩnh viễn và kiểm soát toàn bộ hạ tầng.
> - **Chỉ thị `USER appuser` cắt đứt chuỗi ở đâu:**
>   - Lệnh `USER appuser` cắt đứt chuỗi tấn công **ngay tại bước 3 và 4**:
>   - Khi ứng dụng bị tấn công RCE, shell kẻ tấn công chiếm được chỉ mang quyền hạn của một người dùng thông thường (`appuser`, `UID 10001`, không có trong sudoers).
>   - Khi không có quyền `root`, kẻ tấn công bị chặn không thể đọc ghi các file nhạy cảm trong hệ thống, không thể tương tác với socket bảo mật, và phần lớn các kỹ thuật vượt rào container (container escape) đòi hỏi quyền root/Linux capabilities đều hoàn toàn vô tác dụng.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> - **Số request tối đa:** **20 request** trong 2 giây liên tiếp.
> - **Cách đạt được:**
>   - Cơ chế fixed window reset bộ đếm vào đúng giây `00` của mỗi phút.
>   - Kẻ tấn công gửi dồn **10 request** vào giây cuối cùng của phút thứ nhất (lúc `10:00:59`). Bộ đếm ghi nhận 10/10 request (hợp lệ).
>   - Ngay 1 giây sau đó (lúc `10:01:00`), đồng hồ nhảy sang phút mới và bộ đếm tự động reset về 0. Kẻ tấn công gửi tiếp **10 request** nữa. Bộ đếm ghi nhận 10/10 request cho phút mới (vẫn hợp lệ).
>   - Kết quả: Có tới 20 request được thực hiện chỉ trong vòng 2 giây (từ 10:00:59 đến 10:01:00) — gấp đôi hạn mức 10 req/phút. Cửa sổ trượt (sliding window) khắc phục triệt để lỗ hổng này vì luôn tính tổng số request trong đúng 60 giây gần nhất tính từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> - **Điểm khác nhau:**
>   - **Rate Limit** giới hạn **số lượng request trong một khoảng thời gian ngắn** (ví dụ 10 req/phút) để chống nghẽn đường truyền, spam và từ chối dịch vụ (DoS), trả về mã `429 Too Many Requests`.
>   - **Cost Guard** giới hạn **tổng chi phí tiền tệ / token trong một chu kỳ dài** (ví dụ $10/tháng/user) để kiểm soát ngân sách hóa đơn API LLM, trả về mã `402 Payment Required`.
> - **Rate limit cho qua nhưng Cost guard phải chặn:**
>   - User chỉ gửi 1 request/phút (hoàn toàn hợp lệ theo rate limit 10 req/phút), nhưng request đó đính kèm một file tài liệu khổng lồ (vài chục nghìn token) hoặc user đã tiêu dùng tới $9.99/$10 ngân sách tháng. Cost guard tính toán thấy chi phí vượt ngân sách còn lại nên trả về `402 Payment Required`.
> - **Cost guard cho qua nhưng Rate limit phải chặn:**
>   - User gửi các câu hỏi siêu ngắn ("hi", "test" tốn rất ít token, chi phí chỉ $0.00001, ngân sách tháng vẫn còn gần như nguyên vẹn $10). Tuy nhiên, user dùng script bắn liên tục 15 request trong 3 giây. Cost guard thấy còn tiền nên đồng ý, nhưng Rate limit phát hiện vượt quá 10 req/phút nên lập tức chặn lại bằng mã `429 Too Many Requests`.


---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện xảy ra:
> 1. **Redis mất kết nối:** Kết nối tới Redis bị gián đoạn tạm thời trong 30 giây.
> 2. **Liveness check đồng loạt thất bại:** Orchestrator (Docker/K8s) định kỳ gọi endpoint healthcheck. Do endpoint kiểm tra cả Redis, cả 3 container agent đều phản hồi lỗi/unhealthy.
> 3. **Restart Storm (Thảm họa restart hàng loạt):** Vì liveness probe thất bại, orchestrator kết luận rằng tiến trình app đã chết và lập tức ra lệnh restart cả 3 container cùng lúc.
> 4. **Hệ thống sập hoàn toàn (CrashLoopBackOff / 100% Downtime):** Trong suốt 30 giây Redis chưa hồi phục, các container vừa khởi động lại tiếp tục bị kiểm tra thất bại và lại bị restart liên tục. Không có container nào sống để phục vụ người dùng.
> 5. **Hậu quả so với việc tách probe:** Nếu tách riêng, `/ready` sẽ trả về 503 để Load Balancer tạm ngừng chuyển traffic vào container, trong khi `/health` vẫn trả về 200 để giữ container tiếp tục sống. Khi Redis có lại, hệ thống phục hồi ngay lập tức mà không phải khởi động lại container.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> - **Khi lưu trong Redis (Stateless - hiện tại):** Con số `history_length` tăng dần đều đặn qua từng lượt hỏi (0 → 2 → 4 → 6...) dù request được Load Balancer điều phối vào bất kỳ container nào trong 3 container, vì cả 3 đều chia sẻ chung một cơ sở dữ liệu Redis.
> - **Nếu lưu trong dict Python (Stateful trong RAM):**
>   - Con số `history_length` sẽ **thay đổi bất thường, nhảy loạn xạ và không tăng đều** (ví dụ: lượt 1 vào A ra 0, lượt 2 vào B ra 0, lượt 3 vào A ra 2, lượt 4 vào C lại ra 0...).
>   - **Nguyên nhân:** Mỗi container chạy trong một không gian bộ nhớ RAM độc lập, container B không thể nhìn thấy biến `dict` nằm trong RAM của container A hay C. Khi Load Balancer phân phối request xoay vòng (round-robin), người dùng sẽ thấy bot bị "mất trí nhớ ngẫu nhiên" tùy vào việc request rơi trúng container nào.


---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> - **Lỗi gặp phải:** Lỗi kết nối Redis trên Render khiến endpoint readiness `/ready` ban đầu không hoạt động được và trả về lỗi `503 Service Unavailable` hoặc timeout khi kiểm tra.
> - **Thông báo lỗi quan sát trong Log:**
>   `redis.exceptions.ConnectionError: Error connecting to redis://localhost:6379/0: [Errno 111] Connection refused`
> - **Cách tìm ra nguyên nhân:**
>   - Truy cập vào tab **Logs** của web service `day12-agent` trên giao diện Render Dashboard.
>   - Quan sát thấy web service container khởi động nhưng khi có request gọi tới `/ready`, app báo không thể kết nối tới `localhost:6379`.
>   - Nhận ra rằng trên môi trường cloud container của Render, Redis không chạy chung `localhost` với app như trên máy dev cá nhân, và biến môi trường `REDIS_URL` chưa được truyền vào đúng đường dẫn Redis service.
> - **Cách sửa:**
>   1. Tạo một Redis instance riêng biệt (`day12-redis`) trên cùng dashboard Render.
>   2. Trong phần thiết lập **Environment Variables** của web service `day12-agent`, liên kết biến `REDIS_URL` với `Internal Redis URL` do Render cung cấp (`redis://red-...:6379`) thông qua tính năng `Add Environment Variable from Service`.
>   3. Nhấn Deploy lại (Manual Deploy). Khi deploy hoàn tất, gọi thử `curl -i https://day12-agent-kzk9.onrender.com/ready` và nhận về ngay mã `HTTP/1.1 200 OK` với body `{"status":"ready","redis":true}`.

