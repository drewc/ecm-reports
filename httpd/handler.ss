(import :std/net/httpd/handler :std/srfi/13)
(export #t (import: :std/net/httpd/handler))

(def (http-request-cookies req)
  (let* ((hs (http-request-headers req))
	 (cj (assget "Cookie" hs))
	 (cookies
          (and cj (map (lambda (c) (match (map string-trim (string-split c #\=))
				([a b] [a . b])))
                       (string-split cj #\;)))))
    (or cookies [])))
