class ApplicationError(Exception):
    """Expected application-layer failure safe to map to an HTTP response."""


class ConflictError(ApplicationError):
    pass


class PopupNoticeOverlapError(ConflictError):
    code = "popup_notice_period_overlap"


class AuthenticationError(ApplicationError):
    pass


class NotFoundError(ApplicationError):
    pass


class ForbiddenError(ApplicationError):
    pass


class RequestValidationError(ApplicationError):
    pass
