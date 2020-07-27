package module

import (
	"fmt"
	"net/http"

	"github.com/snapcoreinc/dih-golang-sdk/handler"
)

// Handle a module invocation
func Handle(ctx handler.Context, req handler.Request) (handler.Response, error) {
	var err error

	message := fmt.Sprintf("Hello world, input was: %s", string(req.Body))

	return handler.Response{
		Body:       []byte(message),
		StatusCode: http.StatusOK,
	}, err
}
