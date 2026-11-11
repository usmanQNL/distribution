# Contributing

Thanks for helping improve the distribution skill.

## License of contributions

This project is licensed under either of the MIT License or the Apache License, Version 2.0, at your option (see `LICENSE`). Unless you explicitly state otherwise, any contribution you intentionally submit for inclusion is dual-licensed the same way, with no additional terms or conditions.

## Developer Certificate of Origin (DCO)

Every commit must be signed off. The sign-off certifies that you wrote the change, or otherwise have the right to submit it under the project's licenses, as described in the Developer Certificate of Origin 1.1 (https://developercertificate.org/):

> By making a contribution to this project, I certify that:
>
> (a) The contribution was created in whole or in part by me and I have the right to submit it under the open source license indicated in the file; or
>
> (b) The contribution is based upon previous work that, to the best of my knowledge, is covered under an appropriate open source license and I have the right under that license to submit that work with modifications, whether created in whole or in part by me, under the same open source license (unless I am permitted to submit under a different license), as indicated in the file; or
>
> (c) The contribution was provided directly to me by some other person who certified (a), (b) or (c) and I have not modified it.
>
> (d) I understand and agree that this project and the contribution are public and that a record of the contribution (including all personal information I submit with it, including my sign-off) is maintained indefinitely and may be redistributed consistent with this project or the open source license(s) involved.

To sign off, add `-s` when you commit:

```sh
git commit -s -m "Describe the change"
```

This adds a line with your name and email from your git config:

```
Signed-off-by: Your Name <you@example.com>
```

CI checks every commit in a pull request and fails if one has no sign-off matching its author (`scripts/check_dco.sh`). Merge commits are skipped.

To sign off commits you already made on your branch, run `git rebase --signoff main` and force-push the branch.

## Pull requests

- Run `scripts/test_skill.sh` before you open a pull request. CI runs it on every pull request, together with shellcheck and actionlint.
- Keep each pull request to one change.
